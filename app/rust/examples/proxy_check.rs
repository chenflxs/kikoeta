// 端到端验证本地流代理：直接调用 api_stream_proxy_url，再经本地端口请求上游。
// 用法：cargo run --example proxy_check -- <settings.db路径> <流URL>
use std::time::Duration;

fn main() {
    let mut args = std::env::args().skip(1);
    let db_path = args.next().expect("缺少 settings db 路径");
    let stream_url = args
        .next()
        .expect("缺少流 URL")
        .replace("%3A", ":")
        .replace("%2F", "/");

    kikoeta_core::api::simple::open_settings(db_path).expect("打开设置库失败");
    let local = kikoeta_core::api::proxy::api_stream_proxy_url(stream_url.clone())
        .expect("获取代理 URL 失败");
    println!("LOCAL: {local}");

    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(60))
        .build()
        .unwrap();
    let resp = client
        .get(&local)
        .header("Range", "bytes=0-1023")
        .send()
        .expect("本地代理请求失败");
    println!("STATUS: {}", resp.status());
    for h in ["content-type", "content-length", "content-range", "accept-ranges"] {
        if let Some(v) = resp.headers().get(h) {
            println!("HDR {h}: {}", v.to_str().unwrap_or("?"));
        }
    }
    let body = resp.bytes().expect("读取响应失败");
    println!("BODYBYTES: {}", body.len());
}
