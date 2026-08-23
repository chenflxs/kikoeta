use std::time::Duration;

use crate::api::simple;

fn http_client() -> Result<reqwest::Client, String> {
    let mut builder = reqwest::Client::builder()
        .user_agent("Kikoeta/0.1 (flutter demo)")
        .timeout(Duration::from_secs(20));
    if let Some(p) = crate::api::simple::http_proxy_config() {
        if let Ok(proxy) = reqwest::Proxy::all(&p) {
            builder = builder.proxy(proxy);
        }
    }
    builder.build().map_err(|e| format!("创建 HTTP 客户端失败: {e}"))
}

pub(crate) fn auth_header(base: &str) -> Option<String> {
    simple::token_for_base(base).map(|t| format!("Bearer {}", t))
}

async fn http_get(client: &reqwest::Client, url: &str, auth: Option<&str>) -> Result<String, String> {
    let mut req = client.get(url);
    if let Some(a) = auth {
        req = req.header("authorization", a);
    }
    let resp = req
        .send()
        .await
        .map_err(|e| format!("网络请求失败: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        let preview: String = text.chars().take(200).collect();
        return Err(format!("HTTP {}: {}", status.as_u16(), preview));
    }
    Ok(text)
}

async fn http_post_json(
    client: &reqwest::Client,
    url: &str,
    auth: Option<&str>,
    body: serde_json::Value,
) -> Result<String, String> {
    let mut req = client.post(url).header("content-type", "application/json");
    if let Some(a) = auth {
        req = req.header("authorization", a);
    }
    let resp = req
        .body(body.to_string())
        .send()
        .await
        .map_err(|e| format!("网络请求失败: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        let preview: String = text.chars().take(200).collect();
        return Err(format!("HTTP {}: {}", status.as_u16(), preview));
    }
    Ok(text)
}

async fn http_put_json(
    client: &reqwest::Client,
    url: &str,
    auth: Option<&str>,
    body: serde_json::Value,
) -> Result<String, String> {
    let mut req = client.put(url).header("content-type", "application/json");
    if let Some(a) = auth {
        req = req.header("authorization", a);
    }
    let resp = req
        .body(body.to_string())
        .send()
        .await
        .map_err(|e| format!("网络请求失败: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        let preview: String = text.chars().take(200).collect();
        return Err(format!("HTTP {}: {}", status.as_u16(), preview));
    }
    Ok(text)
}

async fn http_delete(client: &reqwest::Client, url: &str, auth: Option<&str>) -> Result<String, String> {
    let mut req = client.delete(url);
    if let Some(a) = auth {
        req = req.header("authorization", a);
    }
    let resp = req
        .send()
        .await
        .map_err(|e| format!("网络请求失败: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        let preview: String = text.chars().take(200).collect();
        return Err(format!("HTTP {}: {}", status.as_u16(), preview));
    }
    Ok(text)
}

fn base_of(base: &str) -> String {
    base.trim_end_matches('/').to_string()
}

pub(crate) fn origin_of(url: &str) -> String {
    if let Some(i) = url.find("://") {
        let rest = &url[i + 3..];
        let host = rest.split('/').next().unwrap_or(rest);
        format!("{}{}", &url[..i + 3], host)
    } else {
        url.to_string()
    }
}

/// 作品列表：GET /api/works?page=&per_page=&order=&sort=&subtitle=&seed=
#[flutter_rust_bridge::frb]
pub async fn api_get_works(
    base: String,
    page: u32,
    per_page: u32,
    order: String,
    sort: String,
    subtitle: Option<bool>,
    seed: Option<String>,
) -> Result<String, String> {
    let mut url = format!(
        "{}/api/works?page={}&per_page={}",
        base_of(&base),
        page,
        per_page
    );
    append_filter_params(&mut url, &order, &sort, subtitle, seed.as_deref());
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// asmr.one 随心听：固定请求服务端的单作品随机接口。
///
/// 该接口与普通作品列表、热门和推荐页面完全独立，不能附带分页、
/// 筛选或 seed 等列表参数。
#[flutter_rust_bridge::frb]
pub async fn api_get_random_work(base: String) -> Result<String, String> {
    let url = format!("{}/api/works?order=betterRandom", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// asmr.one 热门页：POST /api/recommender/popular。
#[flutter_rust_bridge::frb]
pub async fn api_get_recommender_popular(
    base: String,
    keyword: String,
    page: u32,
    subtitle: bool,
) -> Result<String, String> {
    let url = format!("{}/api/recommender/popular", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = recommender_body(&keyword, page, subtitle, None);
    http_post_json(&client, &url, auth.as_deref(), body).await
}

/// asmr.one 推荐页：POST /api/recommender/recommend-for-user。
#[flutter_rust_bridge::frb]
pub async fn api_get_recommender_recommend(
    base: String,
    recommender_uuid: String,
    keyword: String,
    page: u32,
    subtitle: bool,
) -> Result<String, String> {
    let url = format!("{}/api/recommender/recommend-for-user", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = recommender_body(&keyword, page, subtitle, Some(&recommender_uuid));
    http_post_json(&client, &url, auth.as_deref(), body).await
}

fn recommender_body(
    keyword: &str,
    page: u32,
    subtitle: bool,
    recommender_uuid: Option<&str>,
) -> serde_json::Value {
    let mut body = serde_json::json!({
        "keyword": keyword,
        "localSubtitledWorks": [],
        "page": page,
        "subtitle": if subtitle { 1 } else { 0 },
    });
    if let Some(uuid) = recommender_uuid.filter(|value| !value.trim().is_empty()) {
        body["recommenderUuid"] = serde_json::Value::String(uuid.to_string());
    }
    body
}

/// 搜索：GET /api/search/{query}?page=&per_page=&order=&sort=&subtitle=
#[flutter_rust_bridge::frb]
pub async fn api_search(
    base: String,
    query: String,
    page: u32,
    per_page: u32,
    order: String,
    sort: String,
    subtitle: Option<bool>,
    seed: Option<String>,
) -> Result<String, String> {
    let q = urlencoding(&query);
    let mut url = format!(
        "{}/api/search/{}?page={}&per_page={}",
        base_of(&base),
        q,
        page,
        per_page
    );
    append_filter_params(&mut url, &order, &sort, subtitle, seed.as_deref());
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

fn append_filter_params(
    url: &mut String,
    order: &str,
    sort: &str,
    subtitle: Option<bool>,
    seed: Option<&str>,
) {
    if !order.is_empty() {
        url.push_str(&format!("&order={}", urlencoding(order)));
    }
    if !sort.is_empty() {
        url.push_str(&format!("&sort={}", urlencoding(sort)));
    }
    if subtitle == Some(true) {
        url.push_str("&subtitle=1");
    }
    if let Some(s) = seed {
        if !s.is_empty() {
            url.push_str(&format!("&seed={}", urlencoding(s)));
        }
    }
}

/// 自建站（kikoeru-express 兼容）作品列表：
/// GET /api/works?page=&order=&sort=&nsfw=&lyric=&seed=
#[flutter_rust_bridge::frb]
pub async fn api_get_custom_works(
    base: String,
    page: u32,
    order: String,
    sort: String,
    nsfw: Option<i32>,
    lyric: Option<String>,
    seed: Option<String>,
) -> Result<String, String> {
    let mut url = format!("{}/api/works?page={}", base_of(&base), page);
    append_custom_params(
        &mut url,
        &order,
        &sort,
        nsfw,
        lyric.as_deref(),
        seed.as_deref(),
    );
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 自建站（kikoeru-express 兼容）搜索：
/// GET /api/search?keyword=&page=&order=&sort=&nsfw=&seed=
#[flutter_rust_bridge::frb]
pub async fn api_search_custom(
    base: String,
    keyword: String,
    page: u32,
    order: String,
    sort: String,
    nsfw: Option<i32>,
    seed: Option<String>,
) -> Result<String, String> {
    let mut url = format!(
        "{}/api/search?keyword={}&page={}",
        base_of(&base),
        urlencoding(&keyword),
        page
    );
    append_custom_params(&mut url, &order, &sort, nsfw, None, seed.as_deref());
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

fn append_custom_params(
    url: &mut String,
    order: &str,
    sort: &str,
    nsfw: Option<i32>,
    lyric: Option<&str>,
    seed: Option<&str>,
) {
    if !order.is_empty() {
        url.push_str(&format!("&order={}", urlencoding(order)));
    }
    if !sort.is_empty() {
        url.push_str(&format!("&sort={}", urlencoding(sort)));
    }
    if let Some(n) = nsfw {
        if n > 0 {
            url.push_str(&format!("&nsfw={n}"));
        }
    }
    if let Some(l) = lyric {
        if !l.is_empty() {
            url.push_str(&format!("&lyric={}", urlencoding(l)));
        }
    }
    if let Some(s) = seed {
        if !s.is_empty() {
            url.push_str(&format!("&seed={}", urlencoding(s)));
        }
    }
}

/// 作品详情：GET /api/work/{rj}
#[flutter_rust_bridge::frb]
pub async fn api_get_work(base: String, rj: String) -> Result<String, String> {
    let url = format!("{}/api/work/{}", base_of(&base), rj);
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 曲目列表：GET /api/tracks/{rj}
#[flutter_rust_bridge::frb]
pub async fn api_get_tracks(base: String, rj: String) -> Result<String, String> {
    let url = format!("{}/api/tracks/{}", base_of(&base), rj);
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 下载任意 URL 的原始字节（用于封面等图片，绕过 dart:io 的 TLS 问题）
#[flutter_rust_bridge::frb]
pub async fn api_get_bytes(url: String) -> Result<Vec<u8>, String> {
    let client = http_client()?;
    let mut req = client.get(&url);
    if let Some(a) = auth_header(&origin_of(&url)) {
        req = req.header("authorization", a);
    }
    let resp = req.send().await
        .map_err(|e| format!("图片请求失败: {e}"))?;
    let status = resp.status();
    let bytes = resp
        .bytes()
        .await
        .map_err(|e| format!("读取图片失败: {e}"))?;
    if !status.is_success() {
        return Err(format!("HTTP {}: {}", status.as_u16(), url));
    }
    Ok(bytes.to_vec())
}

/// 连接检测：GET /api/health，返回耗时
#[flutter_rust_bridge::frb]
pub async fn api_health(base: String) -> Result<String, String> {
    let url = format!("{}/api/health", base_of(&base));
    let client = http_client()?;
    let start = std::time::Instant::now();
    let mut req = client.get(&url);
    if let Some(a) = auth_header(&base) {
        req = req.header("authorization", a);
    }
    let resp = req.send().await
        .map_err(|e| format!("连接失败: {e}"))?;
    let ms = start.elapsed().as_millis();
    let status = resp.status();
    if status.is_success() {
        Ok(format!("正常 · {}ms", ms))
    } else {
        Err(format!("HTTP {}", status.as_u16()))
    }
}

/// 使用用户自己的账号登录服务器（one 站 / 自建站），成功返回并保存 token
#[flutter_rust_bridge::frb]
pub async fn api_login(base: String, name: String, password: String) -> Result<String, String> {
    let url = format!("{}/api/auth/me", base_of(&base));
    let client = http_client()?;
    let body = serde_json::json!({ "name": name, "password": password });
    let resp = client
        .post(&url)
        .header("authorization", "Bearer ")
        .header("content-type", "application/json")
        .body(body.to_string())
        .send()
        .await
        .map_err(|e| format!("登录请求失败: {e}"))?;
    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        let msg = serde_json::from_str::<serde_json::Value>(&text)
            .ok()
            .and_then(|v| v["error"].as_str().map(String::from))
            .unwrap_or_else(|| format!("HTTP {}", status.as_u16()));
        return Err(msg);
    }
    let v: serde_json::Value = serde_json::from_str(&text).map_err(|e| e.to_string())?;
    let token = v["token"]
        .as_str()
        .or_else(|| v["access_token"].as_str())
        .or_else(|| v["accessToken"].as_str())
        .or_else(|| v.get("data").and_then(|d| d["token"].as_str()))
        .ok_or_else(|| "响应中未找到 token".to_string())?
        .to_string();
    simple::save_token_for_base(&base, &token)?;
    Ok(token)
}

/// 获取作品歌词：GET /api/media/check-lrc/{rj}（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_check_lrc(base: String, rj: String) -> Result<String, String> {
    let url = format!("{}/api/media/check-lrc/{}", base_of(&base), rj);
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 歌单列表：GET /api/playlist/get-playlists（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_get_playlists(base: String) -> Result<String, String> {
    let url = format!(
        "{}/api/playlist/get-playlists?page=1&per_page=100",
        base_of(&base)
    );
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 歌单作品：GET /api/playlist/get-playlist-works?id=...（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_get_playlist_works(
    base: String,
    id: String,
    page: u32,
    per_page: u32,
) -> Result<String, String> {
    let url = format!(
        "{}/api/playlist/get-playlist-works?id={}&page={}&per_page={}",
        base_of(&base),
        urlencoding(&id),
        page,
        per_page
    );
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

/// 添加作品到歌单：POST /api/playlist/add-works-to-playlist
#[flutter_rust_bridge::frb]
pub async fn api_playlist_add_works(
    base: String,
    playlist_id: String,
    work_ids: Vec<String>,
) -> Result<String, String> {
    let url = format!("{}/api/playlist/add-works-to-playlist", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = serde_json::json!({ "id": playlist_id, "works": work_ids });
    http_post_json(&client, &url, auth.as_deref(), body).await
}

/// 从歌单移除作品：POST /api/playlist/remove-works-from-playlist
#[flutter_rust_bridge::frb]
pub async fn api_playlist_remove_works(
    base: String,
    playlist_id: String,
    work_ids: Vec<String>,
) -> Result<String, String> {
    let url = format!("{}/api/playlist/remove-works-from-playlist", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = serde_json::json!({ "id": playlist_id, "works": work_ids });
    http_post_json(&client, &url, auth.as_deref(), body).await
}

/// 收藏作品：创建无评分的 listening 评价。
#[flutter_rust_bridge::frb]
pub async fn api_create_favorite_review(
    base: String,
    user_name: String,
    work_id: u64,
) -> Result<String, String> {
    let url = format!(
        "{}/api/review?starOnly=false&progressOnly=true",
        base_of(&base)
    );
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = serde_json::json!({
        "progress": "listening",
        "user_name": user_name,
        "work_id": work_id,
    });
    http_put_json(&client, &url, auth.as_deref(), body).await
}

/// 取消收藏：删除该作品的评价。
#[flutter_rust_bridge::frb]
pub async fn api_delete_favorite_review(base: String, work_id: u64) -> Result<String, String> {
    let url = format!("{}/api/review?work_id={}", base_of(&base), work_id);
    let client = http_client()?;
    let auth = auth_header(&base);
    http_delete(&client, &url, auth.as_deref()).await
}

/// 我的评价/收藏列表：GET /api/review（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_get_my_reviews(
    base: String,
    page: u32,
    per_page: u32,
) -> Result<String, String> {
    let url = format!(
        "{}/api/review?page={}&per_page={}",
        base_of(&base),
        page,
        per_page
    );
    let client = http_client()?;
    let auth = auth_header(&base);
    http_get(&client, &url, auth.as_deref()).await
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
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
