use crate::api::simple;

fn http_client() -> Result<reqwest::Client, String> {
    crate::api::http_client::api_client()
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

/// asmr.one 相似作品：POST /api/recommender/item-neighbors。
///
/// 请求体与站点一致：`itemId` 是作品数字 id，`keyword` 用于叠加高级筛选；
/// 站点默认每页 20 条，这里显式传页码以便继续加载剩余结果。
/// 该接口只属于 one 站，自建站不支持。
#[flutter_rust_bridge::frb]
pub async fn api_get_recommender_neighbors(
    base: String,
    item_id: String,
    keyword: String,
    page: u32,
) -> Result<String, String> {
    let url = format!("{}/api/recommender/item-neighbors", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = neighbors_body(&item_id, &keyword, page);
    http_post_json(&client, &url, auth.as_deref(), body).await
}

fn neighbors_body(item_id: &str, keyword: &str, page: u32) -> serde_json::Value {
    serde_json::json!({
        "keyword": keyword,
        "itemId": item_id,
        "localSubtitledWorks": [],
        "withPlaylistStatus": [],
        "page": page,
    })
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
    let is_advance = keyword.starts_with("[{") && keyword.ends_with("}]");
    let mut url = if is_advance {
        format!(
            "{}/api/search?keyword={}&isAdvance=1&page={}",
            base_of(&base),
            urlencoding(&keyword),
            page
        )
    } else {
        format!(
            "{}/api/search?keyword={}&page={}",
            base_of(&base),
            urlencoding(&keyword),
            page
        )
    };
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

/// 作品详情（含当前账号的评分/标记/评论）：GET /api/work/{rj}?v=2
#[flutter_rust_bridge::frb]
pub async fn api_get_work_v2(base: String, rj: String) -> Result<String, String> {
    let url = format!("{}/api/work/{}?v=2", base_of(&base), rj);
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
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!(
        "{}/api/playlist/get-playlists?page=1&pageSize=100&filterBy=all",
        base_of(&base)
    );
    match http_get(&client, &rpc_url, auth.as_deref()).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: GET /api/playlists
            let rest_url = format!("{}/api/playlists", base_of(&base));
            http_get(&client, &rest_url, auth.as_deref()).await
        }
        Err(e) => Err(e),
    }
}

/// 新建歌单：POST /api/playlist/create-playlist（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_create_playlist(
    base: String,
    name: String,
    description: String,
    privacy: u32,
) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!("{}/api/playlist/create-playlist", base_of(&base));
    let body = create_playlist_body(&name, &description, privacy);
    match http_post_json(&client, &rpc_url, auth.as_deref(), body).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: POST /api/playlists
            let rest_url = format!("{}/api/playlists", base_of(&base));
            let rest_body = serde_json::json!({
                "name": name,
                "description": description,
                "privacy": privacy,
            });
            http_post_json(&client, &rest_url, auth.as_deref(), rest_body).await
        }
        Err(e) => Err(e),
    }
}

fn create_playlist_body(name: &str, description: &str, privacy: u32) -> serde_json::Value {
    serde_json::json!({
        "name": name,
        "privacy": privacy,
        "locale": "zh-CN",
        "works": [],
        "description": description,
    })
}

/// 收藏/导入别人的歌单：POST /api/playlist/like-playlist（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_like_playlist(base: String, id: String) -> Result<String, String> {
    let url = format!("{}/api/playlist/like-playlist", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = serde_json::json!({ "id": id });
    http_post_json(&client, &url, auth.as_deref(), body).await
}

/// 取消收藏别人的歌单：POST /api/playlist/remove-like-playlist（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_remove_like_playlist(base: String, id: String) -> Result<String, String> {
    let url = format!("{}/api/playlist/remove-like-playlist", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = serde_json::json!({ "id": id });
    http_post_json(&client, &url, auth.as_deref(), body).await
}

/// 歌单详情：GET /api/playlist/get-playlist-metadata?id=...（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_get_playlist_metadata(base: String, id: String) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!(
        "{}/api/playlist/get-playlist-metadata?id={}",
        base_of(&base),
        urlencoding(&id)
    );
    match http_get(&client, &rpc_url, auth.as_deref()).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: GET /api/playlists/:id
            let rest_url = format!("{}/api/playlists/{}", base_of(&base), urlencoding(&id));
            let res = http_get(&client, &rest_url, auth.as_deref()).await?;
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&res) {
                if let Some(pl) = val.get("playlist") {
                    return Ok(pl.to_string());
                }
            }
            Ok(res)
        }
        Err(e) => Err(e),
    }
}

/// 修改歌单信息：POST /api/playlist/edit-playlist-metadata（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_edit_playlist_metadata(
    base: String,
    id: String,
    name: String,
    privacy: u32,
    description: String,
) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!("{}/api/playlist/edit-playlist-metadata", base_of(&base));
    let body = edit_playlist_body(&id, &name, privacy, &description);
    match http_post_json(&client, &rpc_url, auth.as_deref(), body).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: PUT /api/playlists/:id
            let rest_url = format!("{}/api/playlists/{}", base_of(&base), urlencoding(&id));
            let rest_body = serde_json::json!({
                "name": name,
                "description": description,
                "privacy": privacy,
            });
            http_put_json(&client, &rest_url, auth.as_deref(), rest_body).await
        }
        Err(e) => Err(e),
    }
}

fn edit_playlist_body(
    id: &str,
    name: &str,
    privacy: u32,
    description: &str,
) -> serde_json::Value {
    serde_json::json!({
        "id": id,
        "data": {
            "name": name,
            "privacy": privacy,
            "description": description,
        },
    })
}

/// 删除自己的歌单：POST /api/playlist/delete-playlist（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_delete_playlist(base: String, id: String) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!("{}/api/playlist/delete-playlist", base_of(&base));
    let body = serde_json::json!({ "id": id });
    match http_post_json(&client, &rpc_url, auth.as_deref(), body).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: DELETE /api/playlists/:id
            let rest_url = format!("{}/api/playlists/{}", base_of(&base), urlencoding(&id));
            http_delete(&client, &rest_url, auth.as_deref()).await
        }
        Err(e) => Err(e),
    }
}

/// 歌单作品：GET /api/playlist/get-playlist-works?id=...（需登录）
#[flutter_rust_bridge::frb]
pub async fn api_get_playlist_works(
    base: String,
    id: String,
    page: u32,
    per_page: u32,
) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!(
        "{}/api/playlist/get-playlist-works?id={}&page={}&pageSize={}",
        base_of(&base),
        urlencoding(&id),
        page,
        per_page
    );
    match http_get(&client, &rpc_url, auth.as_deref()).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: GET /api/playlists/:id (包含完整 works)
            let rest_url = format!("{}/api/playlists/{}", base_of(&base), urlencoding(&id));
            let text = http_get(&client, &rest_url, auth.as_deref()).await?;
            complete_playlist_works(&text, page)
        }
        Err(e) => Err(e),
    }
}

// REST 返回完整歌单；一次交付全部作品，并通知调用者停止分页。
fn complete_playlist_works(text: &str, page: u32) -> Result<String, String> {
    let mut value: serde_json::Value =
        serde_json::from_str(text).map_err(|e| format!("歌单响应解析失败: {e}"))?;
    let works = value
        .get_mut("works")
        .and_then(|w| w.as_array_mut())
        .ok_or_else(|| "歌单响应缺少 works 数组".to_string())?;
    let total = works.len();
    if page > 1 {
        works.clear();
    }
    value["pagination"] = serde_json::json!({
        "currentPage": page.max(1),
        "pageSize": total.max(1),
        "totalCount": total,
    });
    Ok(value.to_string())
}

/// 添加作品到歌单：POST /api/playlist/add-works-to-playlist
#[flutter_rust_bridge::frb]
pub async fn api_playlist_add_works(
    base: String,
    playlist_id: String,
    work_ids: Vec<String>,
) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!("{}/api/playlist/add-works-to-playlist", base_of(&base));
    let body = serde_json::json!({ "id": playlist_id, "works": work_ids });
    match http_post_json(&client, &rpc_url, auth.as_deref(), body).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: POST /api/playlists/:id/works
            let rest_url = format!("{}/api/playlists/{}/works", base_of(&base), urlencoding(&playlist_id));
            let num_ids: Vec<serde_json::Value> = work_ids
                .iter()
                .map(|id_str| {
                    let digits = id_str.trim().trim_start_matches(|c| c == 'R' || c == 'r' || c == 'J' || c == 'j');
                    if let Ok(n) = digits.parse::<u64>() {
                        serde_json::json!(n)
                    } else {
                        serde_json::json!(id_str)
                    }
                })
                .collect();
            let rest_body = serde_json::json!({ "workIds": num_ids });
            http_post_json(&client, &rest_url, auth.as_deref(), rest_body).await
        }
        Err(e) => Err(e),
    }
}

/// 从歌单移除作品：POST /api/playlist/remove-works-from-playlist
///
/// one 站该接口要求作品数字 id（`works: [1367541]`），这里把传入的
/// 字符串 id 尽量转成数字，解析失败时保持字符串兜底。
#[flutter_rust_bridge::frb]
pub async fn api_playlist_remove_works(
    base: String,
    playlist_id: String,
    work_ids: Vec<String>,
) -> Result<String, String> {
    let client = http_client()?;
    let auth = auth_header(&base);
    let rpc_url = format!("{}/api/playlist/remove-works-from-playlist", base_of(&base));
    let body = remove_works_body(&playlist_id, &work_ids);
    match http_post_json(&client, &rpc_url, auth.as_deref(), body).await {
        Ok(text) => Ok(text),
        Err(e) if e.contains("404") => {
            // Number178 / 自建库 RESTful 路由回退: DELETE /api/playlists/:id/works/:workId
            for work_id in work_ids {
                let digits = work_id.trim().trim_start_matches(|c| c == 'R' || c == 'r' || c == 'J' || c == 'j');
                let rest_url = format!(
                    "{}/api/playlists/{}/works/{}",
                    base_of(&base),
                    urlencoding(&playlist_id),
                    urlencoding(digits)
                );
                http_delete(&client, &rest_url, auth.as_deref()).await?;
            }
            Ok(r#"{"removed":true}"#.to_string())
        }
        Err(e) => Err(e),
    }
}

fn remove_works_body(playlist_id: &str, work_ids: &[String]) -> serde_json::Value {
    let ids: Vec<serde_json::Value> = work_ids
        .iter()
        .map(|id| match id.parse::<u64>() {
            Ok(number) => serde_json::json!(number),
            Err(_) => serde_json::Value::String(id.clone()),
        })
        .collect();
    serde_json::json!({ "id": playlist_id, "works": ids })
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

/// 提交评价与标记：PUT /api/review
///
/// 只发送调用方明确提供的字段——快速打分只传 rating，进度与评论保持
/// 服务端原值；对话框确认时再一并提交进度和评论正文。
#[flutter_rust_bridge::frb]
pub async fn api_submit_review(
    base: String,
    work_id: u64,
    rating: Option<f64>,
    review_text: Option<String>,
    progress: Option<String>,
) -> Result<String, String> {
    let mut url = format!("{}/api/review", base_of(&base));
    if rating.is_none() && review_text.is_none() && progress.is_some() {
        url.push_str("?starOnly=false&progressOnly=true");
    } else if rating.is_some() && review_text.is_none() && progress.is_none() {
        url.push_str("?starOnly=true&progressOnly=false");
    } else if rating.is_some() || review_text.is_some() || progress.is_some() {
        url.push_str("?starOnly=false&progressOnly=false");
    }
    let client = http_client()?;
    let auth = auth_header(&base);
    let body = review_body(
        work_id,
        rating,
        review_text.as_deref(),
        progress.as_deref(),
    );
    http_put_json(&client, &url, auth.as_deref(), body).await
}

fn review_body(
    work_id: u64,
    rating: Option<f64>,
    review_text: Option<&str>,
    progress: Option<&str>,
) -> serde_json::Value {
    let mut body = serde_json::json!({ "work_id": work_id });
    if let Some(value) = rating {
        body["rating"] = serde_json::json!(value);
    }
    if let Some(value) = review_text {
        body["review_text"] = serde_json::Value::String(value.to_string());
    }
    if let Some(value) = progress {
        body["progress"] = serde_json::Value::String(value.to_string());
    }
    body
}

/// 取消打分：PUT /api/review，把 rating 显式置为 null，其余字段保持不变。
#[flutter_rust_bridge::frb]
pub async fn api_clear_review_rating(base: String, work_id: u64) -> Result<String, String> {
    let url = format!("{}/api/review?starOnly=true&progressOnly=false", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    http_put_json(&client, &url, auth.as_deref(), clear_rating_body(work_id)).await
}

fn clear_rating_body(work_id: u64) -> serde_json::Value {
    serde_json::json!({ "work_id": work_id, "rating": serde_json::Value::Null })
}

/// 取消播放标记：PUT /api/review，把 progress 显式置为 null，评分与评论保持不变。
#[flutter_rust_bridge::frb]
pub async fn api_clear_review_progress(base: String, work_id: u64) -> Result<String, String> {
    let url = format!("{}/api/review?starOnly=false&progressOnly=true", base_of(&base));
    let client = http_client()?;
    let auth = auth_header(&base);
    http_put_json(&client, &url, auth.as_deref(), clear_progress_body(work_id)).await
}

fn clear_progress_body(work_id: u64) -> serde_json::Value {
    serde_json::json!({ "work_id": work_id, "progress": serde_json::Value::Null })
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
    order: String,
    sort: String,
    filter: Option<String>,
) -> Result<String, String> {
    let mut url = format!(
        "{}/api/review?page={}&per_page={}&order={}&sort={}",
        base_of(&base),
        page,
        per_page,
        urlencoding(&order),
        urlencoding(&sort),
    );
    if let Some(value) = filter.filter(|value| !value.is_empty()) {
        url.push_str("&filter=");
        url.push_str(&urlencoding(&value));
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::http_client::{test_support::TestServer, ClientPool};
    use std::time::Duration;

    #[test]
    fn shared_api_connections_do_not_retain_request_authentication() {
        let first = TestServer::new(|_| "ok".to_string());
        let second = TestServer::new(|_| "ok".to_string());
        let pool =
            ClientPool::for_testing("Kikoeta/0.1 (flutter demo)", Duration::from_secs(20));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            for auth in [Some("Bearer first"), None, Some("Bearer changed")] {
                let client = pool.client_for_proxy(None).unwrap();
                assert_eq!(http_get(&client, &first.base, auth).await.unwrap(), "ok");
            }
            for auth in [Some("Bearer other-site"), None] {
                let client = pool.client_for_proxy(None).unwrap();
                assert_eq!(http_get(&client, &second.base, auth).await.unwrap(), "ok");
            }
        });
        assert_eq!(first.connections(), 1);
        assert_eq!(second.connections(), 1);
        let headers = |server: &TestServer| {
            server.records().into_iter()
                .map(|request| request.authorization).collect::<Vec<_>>()
        };
        assert_eq!(headers(&first), vec![
            Some("Bearer first".to_string()), None, Some("Bearer changed".to_string()),
        ]);
        assert_eq!(headers(&second), vec![Some("Bearer other-site".to_string()), None]);
    }
    #[test]
    fn an_http_error_can_be_retried_on_the_shared_connection() {
        let server = TestServer::with_response(|target| {
            if target == "/failed" {
                tiny_http::Response::from_string("服务暂时不可用".repeat(50)).with_status_code(503)
            } else {
                tiny_http::Response::from_string("loaded")
            }
        });
        let pool = ClientPool::for_testing("Kikoeta/0.1 (flutter demo)", Duration::from_secs(2));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let error = http_get(&pool.client_for_proxy(None).unwrap(),
                &format!("{}/failed", server.base), None).await.unwrap_err();
            assert!(error.starts_with("HTTP 503: "));
            assert_eq!(error.chars().count(), "HTTP 503: ".chars().count() + 200);
            assert_eq!(http_get(&pool.client_for_proxy(None).unwrap(),
                &format!("{}/retry", server.base), None).await.unwrap(), "loaded");
        });
        assert_eq!(server.connections(), 1);
    }

    #[test]
    fn simultaneous_page_requests_keep_their_own_responses_and_authentication() {
        use std::io::{BufRead, BufReader, Write};
        use std::sync::{Arc, Mutex};
        use std::time::Instant;

        // Serve each socket independently. tiny_http's connection task pool
        // can queue a burst behind idle keepalive sockets in the test fixture.
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        listener.set_nonblocking(true).unwrap();
        let records = Arc::new(Mutex::new(Vec::new()));
        let received = records.clone();
        let server = std::thread::spawn(move || {
            let deadline = Instant::now() + Duration::from_secs(10);
            let mut workers = Vec::new();
            while workers.len() < 12 {
                match listener.accept() {
                    Ok((mut socket, _)) => {
                        let received = received.clone();
                        workers.push(std::thread::spawn(move || {
                            socket.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
                            socket.set_write_timeout(Some(Duration::from_secs(5))).unwrap();
                            let mut reader = BufReader::new(socket.try_clone().unwrap());
                            let mut line = String::new();
                            reader.read_line(&mut line).unwrap();
                            let path = line.split_whitespace().nth(1).unwrap().to_string();
                            let mut auth = None;
                            loop {
                                line.clear();
                                assert!(reader.read_line(&mut line).unwrap() > 0);
                                if line == "\r\n" {
                                    break;
                                }
                                if let Some((name, value)) = line.split_once(':') {
                                    if name.eq_ignore_ascii_case("authorization") {
                                        auth = Some(value.trim().to_string());
                                    }
                                }
                            }
                            received.lock().unwrap().push((path.clone(), auth));
                            write!(socket,
                                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                                path.len(), path).unwrap();
                            socket.flush().unwrap();
                        }));
                    }
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "Missing page requests");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("Accept failed: {error}"),
                }
            }
            for worker in workers {
                worker.join().unwrap();
            }
        });
        let pool = ClientPool::for_testing("Kikoeta/0.1 (flutter demo)", Duration::from_secs(20));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let mut pending = Vec::new();
            for index in 0..12 {
                let client = pool.client_for_proxy(None).unwrap();
                let base = base.clone();
                pending.push(tokio::spawn(async move {
                    let path = format!("/work/{index}");
                    let auth = format!("Bearer session-{index}");
                    assert_eq!(http_get(&client, &format!("{base}{path}"), Some(&auth)).await.unwrap(), path);
                }));
            }
            for request in pending {
                request.await.unwrap();
            }
        });
        server.join().unwrap();
        let records = records.lock().unwrap();
        assert_eq!(records.len(), 12);
        for (path, auth) in records.iter() {
            let index = path.strip_prefix("/work/").unwrap();
            assert_eq!(*auth, Some(format!("Bearer session-{index}")));
        }
    }

    #[test]
    fn item_neighbors_body_matches_the_one_site_request() {
        let body = neighbors_body("1722779", "", 1);
        assert_eq!(body["itemId"], "1722779");
        assert_eq!(body["keyword"], "");
        assert_eq!(body["page"], 1);
        assert_eq!(body["localSubtitledWorks"], serde_json::json!([]));
        assert_eq!(body["withPlaylistStatus"], serde_json::json!([]));

        let filtered = neighbors_body("1722779", "$age:adult$", 3);
        assert_eq!(filtered["keyword"], "$age:adult$");
        assert_eq!(filtered["page"], 3);
    }

    #[test]
    fn rest_playlist_delivers_all_works_and_ends_pagination() {
        for total in [0, 20, 1000] {
            let works: Vec<_> = (0..total)
                .map(|id| serde_json::json!({"id": id}))
                .collect();
            let text = serde_json::json!({"works": works}).to_string();
            let first: serde_json::Value =
                serde_json::from_str(&complete_playlist_works(&text, 1).unwrap()).unwrap();
            assert_eq!(first["works"].as_array().unwrap().len(), total);
            assert_eq!(first["pagination"]["totalCount"], total);
            assert_eq!(first["pagination"]["pageSize"], total.max(1));
            let later: serde_json::Value =
                serde_json::from_str(&complete_playlist_works(&text, 2).unwrap()).unwrap();
            assert!(later["works"].as_array().unwrap().is_empty());
        }
        assert!(complete_playlist_works("not json", 1).is_err());
        assert!(complete_playlist_works(r#"{"playlist":{}}"#, 1).is_err());
    }

    #[test]
    fn playlist_works_fallback_fetches_a_large_playlist_once() {
        use crate::api::http_client::test_support::TestServer;

        let server = TestServer::with_response(|target| {
            if target.starts_with("/api/playlist/get-playlist-works?") {
                tiny_http::Response::from_string("missing route").with_status_code(404)
            } else {
                assert_eq!(target, "/api/playlists/list-1");
                let works: Vec<_> = (0..1000)
                    .map(|id| serde_json::json!({"id": id}))
                    .collect();
                tiny_http::Response::from_string(serde_json::json!({"works": works}).to_string())
            }
        });
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let text = runtime.block_on(api_get_playlist_works(
            server.base.clone(), "list-1".to_string(), 1, 20,
        )).unwrap();
        let page: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(page["works"].as_array().unwrap().len(), 1000);
        assert_eq!(page["pagination"]["pageSize"], 1000);
        assert_eq!(page["pagination"]["totalCount"], 1000);
        assert_eq!(server.records().len(), 2);
    }

    #[test]
    fn playlist_works_rpc_preserves_server_pagination() {
        use crate::api::http_client::test_support::TestServer;

        let response = serde_json::json!({
            "works": [{"id": 1}],
            "pagination": {"currentPage": 2, "pageSize": 20, "totalCount": 1000},
        }).to_string();
        let expected = response.clone();
        let server = TestServer::new(move |_| response.clone());
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let actual = runtime.block_on(api_get_playlist_works(
            server.base.clone(), "list-1".to_string(), 2, 20,
        )).unwrap();
        assert_eq!(actual, expected);
        let records = server.records();
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].target,
            "/api/playlist/get-playlist-works?id=list-1&page=2&pageSize=20");
    }

    #[test]
    fn create_playlist_body_matches_the_one_site_request() {
        let body = create_playlist_body("My List", "描述", 1);
        assert_eq!(body["name"], "My List");
        assert_eq!(body["privacy"], 1);
        assert_eq!(body["locale"], "zh-CN");
        assert_eq!(body["description"], "描述");
        assert_eq!(body["works"], serde_json::json!([]));
    }

    #[test]
    fn remove_works_body_sends_numeric_work_ids() {
        let body = remove_works_body(
            "list-1",
            &["1367541".to_string(), "RJ0001".to_string()],
        );
        assert_eq!(body["id"], "list-1");
        assert_eq!(body["works"][0], 1367541);
        assert_eq!(body["works"][1], "RJ0001");
    }

    #[test]
    fn edit_playlist_body_wraps_metadata_in_data() {
        let body = edit_playlist_body("list-1", "新名称", 2, "新描述");
        assert_eq!(body["id"], "list-1");
        assert_eq!(body["data"]["name"], "新名称");
        assert_eq!(body["data"]["privacy"], 2);
        assert_eq!(body["data"]["description"], "新描述");
    }

    #[test]
    fn review_body_only_contains_the_fields_being_changed() {
        let quick = review_body(1722779, Some(4.5), None, None);
        assert_eq!(quick["work_id"], 1722779);
        assert_eq!(quick["rating"], 4.5);
        assert!(quick.get("review_text").is_none());
        assert!(quick.get("progress").is_none());

        let full = review_body(1722779, Some(5.0), Some("好"), Some("listened"));
        assert_eq!(full["rating"], 5.0);
        assert_eq!(full["review_text"], "好");
        assert_eq!(full["progress"], "listened");

        let cleared = clear_rating_body(1722779);
        assert_eq!(cleared["work_id"], 1722779);
        assert!(cleared["rating"].is_null());

        let unmarked = clear_progress_body(1722779);
        assert_eq!(unmarked["work_id"], 1722779);
        assert!(unmarked["progress"].is_null());
    }
}
