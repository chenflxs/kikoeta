//! 本地流代理：mpv 走 http://127.0.0.1:<port>/stream?url=...，
//! 由 reqwest/rustls 代替 mpv 完成到 asmr.one 的 TLS 握手（Windows Schannel 在此网络下会被重置）。

use std::sync::Mutex;
use std::sync::OnceLock;
use std::time::Duration;

use tiny_http::{Header, Method, Response, Server, StatusCode};

use crate::api::kikoeru_api;

static PROXY_PORT: Mutex<Option<u16>> = Mutex::new(None);
type StreamClient = (Option<String>, reqwest::blocking::Client);

static CLIENT: OnceLock<Mutex<Option<StreamClient>>> = OnceLock::new();

fn proxy_client() -> Result<reqwest::blocking::Client, String> {
    let configured_proxy = crate::api::simple::http_proxy_config();
    let mut cached = CLIENT
        .get_or_init(|| Mutex::new(None))
        .lock()
        .map_err(|e| e.to_string())?;

    if let Some((proxy, client)) = cached.as_ref() {
        if *proxy == configured_proxy {
            return Ok(client.clone());
        }
    }

    let client = {
        let mut builder = reqwest::blocking::Client::builder()
            .user_agent("Kikoeta/0.1 (stream proxy)")
            .connect_timeout(Duration::from_secs(20));
        // 注意：不能设总超时/读超时——长音频流的 body 读取会持续数十分钟。
        // 同一代理配置下复用连接池；配置变更时立即换用新的客户端。
        if let Some(proxy_url) = configured_proxy.as_deref() {
            let proxy = reqwest::Proxy::all(proxy_url)
                .map_err(|e| format!("HTTP 代理地址无效: {e}"))?;
            builder = builder.proxy(proxy);
        }
        builder
            .build()
            .map_err(|e| format!("创建流媒体 HTTP 客户端失败: {e}"))?
    };
    *cached = Some((configured_proxy, client.clone()));
    Ok(client)
}

/// 把一个远程媒体 URL 转成本地代理 URL（首次调用会启动本地代理）。
#[flutter_rust_bridge::frb(sync)]
pub fn api_stream_proxy_url(url: String) -> Result<String, String> {
    let port = ensure_proxy()?;
    Ok(format!(
        "http://127.0.0.1:{}/stream?url={}",
        port,
        percent_encode(&url)
    ))
}

fn ensure_proxy() -> Result<u16, String> {
    if let Some(p) = *PROXY_PORT.lock().map_err(|e| e.to_string())? {
        return Ok(p);
    }
    let server =
        Server::http("127.0.0.1:0").map_err(|e| format!("启动本地流代理失败: {e}"))?;
    let port = server
        .server_addr()
        .to_ip()
        .map(|a| a.port())
        .unwrap_or(0);
    std::thread::Builder::new()
        .name("kikoeta-stream-proxy".to_string())
        .spawn(move || {
            for request in server.incoming_requests() {
                // 每个请求独立线程：正在播放的流不会阻塞 seek / 探测请求
                let _ = std::thread::Builder::new()
                    .name("stream-proxy-req".to_string())
                    .spawn(move || {
                        let _ = handle_request(request);
                    });
            }
        })
        .map_err(|e| format!("启动代理线程失败: {e}"))?;
    *PROXY_PORT.lock().map_err(|e| e.to_string())? = Some(port);
    Ok(port)
}

fn handle_request(request: tiny_http::Request) -> Result<(), String> {
    if request.method() != &Method::Get && request.method() != &Method::Head {
        let _ = request.respond(
            Response::from_string("method not allowed").with_status_code(StatusCode(405)),
        );
        return Ok(());
    }
    let (path, query) = match request.url().split_once('?') {
        Some((p, q)) => (p, q),
        None => (request.url(), ""),
    };
    if path != "/stream" {
        let _ = request
            .respond(Response::from_string("not found").with_status_code(StatusCode(404)));
        return Ok(());
    }
    let target = query_param(query, "url").ok_or_else(|| "缺少 url 参数".to_string())?;

    let mut req = proxy_client()?.get(&target);
    if let Some(a) = kikoeru_api::auth_header(&kikoeru_api::origin_of(&target)) {
        req = req.header("authorization", a);
    }
    // 透传 Range，保证拖动进度条时 mpv 的 seek 可用
    if let Some(range) = request.headers().iter().find(|h| h.field.equiv("Range")) {
        req = req.header("range", range.value.as_str());
    }
    let resp = req
        .send()
        .map_err(|e| format!("转发流请求失败: {e}"))?;

    let status = resp.status().as_u16();
    if status >= 400 {
        let _ = request.respond(
            Response::from_string(format!("upstream error {status}"))
                .with_status_code(StatusCode(status)),
        );
        return Ok(());
    }

    let mut headers = Vec::new();
    for name in [
        "content-type",
        "content-length",
        "accept-ranges",
        "content-range",
        "content-disposition",
        "etag",
        "last-modified",
        "cache-control",
    ] {
        if let Some(v) = resp.headers().get(name) {
            if let Ok(s) = v.to_str() {
                if let Ok(h) = Header::from_bytes(name.as_bytes(), s.as_bytes()) {
                    headers.push(h);
                }
            }
        }
    }
    let len = resp.content_length().map(|l| l as usize);
    let response = Response::new(StatusCode(status), headers, resp, len, None)
        // 有 Content-Length 时用 Identity 传输，避免 chunked（影响 mpv seek）
        .with_chunked_threshold(usize::MAX);
    request
        .respond(response)
        .map_err(|e| format!("回写流响应失败: {e}"))?;
    Ok(())
}

fn query_param(query: &str, key: &str) -> Option<String> {
    for pair in query.split('&') {
        if let Some((k, v)) = pair.split_once('=') {
            if k == key {
                return Some(percent_decode(v));
            }
        }
    }
    None
}

fn percent_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.as_bytes() {
        match *b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*b as char)
            }
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

fn percent_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            if let (Some(hi), Some(lo)) = (hex_val(b[i + 1]), hex_val(b[i + 2])) {
                out.push(hi * 16 + lo);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex_val(c: u8) -> Option<u8> {
    match c {
        b'0'..=b'9' => Some(c - b'0'),
        b'a'..=b'f' => Some(c - b'a' + 10),
        b'A'..=b'F' => Some(c - b'A' + 10),
        _ => None,
    }
}

/// 供其它模块查询当前代理端口（测试/调试用）
#[allow(dead_code)]
pub fn proxy_port() -> Option<u16> {
    *PROXY_PORT.lock().ok()?
}
