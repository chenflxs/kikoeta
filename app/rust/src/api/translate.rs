//! AI 翻译（OpenAI 兼容接口，可配置 base_url / model / api_key）。

use std::time::Duration;

fn translation_prompt(target_language: &str) -> String {
    let language = match target_language.trim() {
        "zh-TW" => "繁体中文",
        "en" => "English",
        _ => "简体中文",
    };
    format!(
        "你是音频作品标题翻译助手。把输入中的每行日文标题翻译为{language}，\\
不翻译 RJ 编号和 .mp3/.flac 等扩展名。\\
每行输入均以 [[KIKOETA_LINE_n]] 开头；每行输出必须保留完全相同的标记，\\
并在标记后紧接该行译文。不得省略、修改、重排或新增标记。\
不要输出解释、Markdown 或其他内容。"
    )
}

fn http_client() -> Result<reqwest::Client, String> {
    let mut builder = reqwest::Client::builder()
        .user_agent("Kikoeta/0.1 (translate)")
        .timeout(Duration::from_secs(30));
    if let Some(p) = crate::api::simple::http_proxy_config() {
        if let Ok(proxy) = reqwest::Proxy::all(&p) {
            builder = builder.proxy(proxy);
        }
    }
    builder.build().map_err(|e| format!("创建 HTTP 客户端失败: {e}"))
}

fn normalize_base(base: &str) -> String {
    base.trim().trim_end_matches('/').to_string()
}

/// 调用 OpenAI 兼容接口翻译文本。text 为多行拼接内容，返回翻译结果。
#[flutter_rust_bridge::frb]
pub async fn api_translate_openai(
    base_url: String,
    model: String,
    api_key: String,
    text: String,
    temperature: f64,
) -> Result<String, String> {
    let base = normalize_base(&base_url);
    if base.is_empty() || model.trim().is_empty() {
        return Err("请先配置 API 地址与模型名".to_string());
    }
    let (target_language, text) = split_translation_target(text);
    if text.trim().is_empty() {
        return Ok(String::new());
    }
    let input = indexed_translation_input(&text);
    let url = format!("{base}/chat/completions");
    let client = http_client()?;
    let mut body = serde_json::json!({
        "model": model.trim(),
        "messages": [
            { "role": "system", "content": translation_prompt(&target_language) },
            { "role": "user", "content": input },
        ],
        "temperature": temperature.clamp(0.0, 2.0),
    });
    apply_thinking_options(&mut body, &base, &model);

    let mut last_err = String::new();
    let mut delay = Duration::from_secs(1);
    for attempt in 0..3 {
        let mut req = client
            .post(&url)
            .header("content-type", "application/json")
            .body(body.to_string());
        let key = api_key.trim();
        if !key.is_empty() {
            req = req.header("authorization", format!("Bearer {key}"));
        }
        match req.send().await {
            Ok(resp) => {
                let status = resp.status();
                let text_body = resp
                    .text()
                    .await
                    .map_err(|e| format!("读取响应失败: {e}"))?;
                if status.is_success() {
                    let content = parse_completion(&text_body)?;
                    return unpack_indexed_translation(&content, text.lines().count());
                }
                last_err = format!("HTTP {}: {}", status.as_u16(), preview(&text_body));
            }
            Err(e) => last_err = format!("请求失败: {e}"),
        }
        if attempt < 2 {
            tokio::time::sleep(delay).await;
            delay *= 2;
        }
    }
    Err(last_err)
}

fn indexed_translation_input(text: &str) -> String {
    text.lines()
        .enumerate()
        .map(|(index, line)| format!("[[KIKOETA_LINE_{index}]]{line}"))
        .collect::<Vec<_>>()
        .join("\n")
}

/// 从 Dart 侧附加的目标语言前缀中取出目标语言。
/// Windows 文本可能使用 CRLF，不能把换行误当成字面量 `\\n`。
fn split_translation_target(text: String) -> (String, String) {
    let Some(rest) = text.strip_prefix("[[KIKOETA_TARGET:") else {
        return ("zh-CN".to_string(), text);
    };
    let Some((target, content)) = rest.split_once("]]") else {
        return ("zh-CN".to_string(), text);
    };
    let Some(content) = content
        .strip_prefix("\r\n")
        .or_else(|| content.strip_prefix('\n'))
    else {
        return ("zh-CN".to_string(), text);
    };
    (target.trim().to_string(), content.to_string())
}

fn apply_thinking_options(body: &mut serde_json::Value, base: &str, model: &str) {
    let provider = format!("{} {}", base.to_ascii_lowercase(), model.to_ascii_lowercase());
    if provider.contains("deepseek") {
        // DeepSeek-compatible APIs use a nested object instead of Qwen's
        // enable_thinking boolean.
        body["thinking"] = serde_json::json!({ "type": "disabled" });
    } else if provider.contains("qwen") || provider.contains("siliconflow") {
        // Qwen/SiliconFlow compatible APIs use this extension.
        body["enable_thinking"] = serde_json::Value::Bool(false);
    }
}

fn parse_completion(body: &str) -> Result<String, String> {
    let v: serde_json::Value =
        serde_json::from_str(body).map_err(|e| format!("响应解析失败: {e}"))?;
    let message = &v["choices"][0]["message"];
    let content = message_content(&message["content"])
        .or_else(|| message_content(&message["text"]))
        .ok_or_else(|| "响应中未找到翻译结果".to_string())?;
    let content = strip_thinking(&content);
    if content.trim().is_empty() {
        return Err("响应中未找到翻译结果（模型只返回了思考内容）".to_string());
    }
    Ok(content.trim().to_string())
}

fn message_content(value: &serde_json::Value) -> Option<String> {
    if let Some(text) = value.as_str() {
        return Some(text.to_string());
    }
    let parts = value.as_array()?;
    let mut out = String::new();
    for part in parts {
        if let Some(text) = part.as_str() {
            out.push_str(text);
        } else if let Some(text) = part["text"].as_str() {
            out.push_str(text);
        }
    }
    (!out.is_empty()).then_some(out)
}

fn strip_thinking(content: &str) -> String {
    let mut output = content.to_string();
    if let Some(start) = output.find("<think>") {
        if let Some(end_rel) = output[start + 7..].find("</think>") {
            output.replace_range(start..start + 7 + end_rel + 8, "");
        } else {
            output.truncate(start);
        }
    }
    output
        .trim()
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim()
        .to_string()
}

fn unpack_indexed_translation(content: &str, line_count: usize) -> Result<String, String> {
    let mut lines = vec![None; line_count];
    let markers = indexed_markers(content);
    if !markers.is_empty() {
        for (position, content_start, index) in markers.iter().copied() {
            if index >= line_count {
                continue;
            }
            let content_end = markers
                .iter()
                .find(|(next_position, _, _)| *next_position > position)
                .map(|(next_position, _, _)| *next_position)
                .unwrap_or(content.len());
            lines[index] = Some(normalize_marked_translation(
                &content[content_start..content_end],
            ));
        }
        return Ok(lines
            .into_iter()
            .map(|line| line.unwrap_or_default())
            .collect::<Vec<_>>()
            .join("\n"));
    }

    // 有些旧兼容模型会忽略标记。只有严格保留行数时才按顺序接收；
    // 行数不符直接报错，避免后一行译文被错误显示到上一首曲目下面。
    let fallback = content.replace("\r\n", "\n");
    if fallback.lines().count() == line_count {
        return Ok(fallback);
    }
    Err(format!(
        "兼容模型未按行返回译文（应有 {line_count} 行，实际 {} 行）",
        fallback.lines().count()
    ))
}

/// 返回标记起始位置、译文开始位置和行号。译文允许另起一行，
/// 兼容部分模型把标记与译文拆开输出的情况。
fn indexed_markers(content: &str) -> Vec<(usize, usize, usize)> {
    const PREFIX: &str = "[[KIKOETA_LINE_";
    let mut markers = Vec::new();
    let mut offset = 0;
    while let Some(relative) = content[offset..].find(PREFIX) {
        let position = offset + relative;
        let index_start = position + PREFIX.len();
        let Some(close_relative) = content[index_start..].find("]]") else {
            offset = index_start;
            continue;
        };
        let close = index_start + close_relative;
        let Ok(index) = content[index_start..close].trim().parse::<usize>() else {
            offset = close + 2;
            continue;
        };
        markers.push((position, close + 2, index));
        offset = close + 2;
    }
    markers
}

fn normalize_marked_translation(segment: &str) -> String {
    segment
        .trim()
        .trim_start_matches(|c: char| c == ':' || c == '-' || c.is_whitespace())
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

fn preview(s: &str) -> String {
    s.chars().take(160).collect()
}

/// Google 网页端翻译接口（无需 Key）。
/// 使用网页端 `client=webapp` 协议和本地计算的 `tk`，避免旧 gtx 客户端
/// 在批量请求时频繁触发 429。
#[flutter_rust_bridge::frb]
pub async fn api_translate_google(
    text: String,
    src: String,
    dst: String,
) -> Result<String, String> {
    if text.trim().is_empty() {
        return Ok(String::new());
    }
    let client = http_client()?;
    let batches = google_batches(&text, 1200);
    let mut translated = Vec::with_capacity(batches.len());
    for batch in batches {
        let mut last_error = String::new();
        // Try the current web protocol first, then fall back to the legacy
        // endpoint when Google rejects the web request with 403/429.
        for (url, webapp) in [
            ("https://translate.google.com/translate_a/single", true),
            ("https://translate.googleapis.com/translate_a/single", false),
        ] {
            match google_request(&client, url, webapp, &batch, &src, &dst).await {
                Ok(result) => {
                    translated.push(result);
                    last_error.clear();
                    break;
                }
                Err(error) => last_error = error,
            }
        }
        if !last_error.is_empty() {
            return Err(last_error);
        }
    }
    Ok(translated.join("\n"))
}

/// Keep requests short enough for the web endpoint and preserve source line
/// boundaries so callers can map translations back to tracks safely.
fn google_batches(text: &str, max_chars: usize) -> Vec<String> {
    let mut batches = Vec::new();
    let mut current = String::new();
    for line in text.lines() {
        let extra = if current.is_empty() { 0 } else { 1 };
        if !current.is_empty() && current.chars().count() + extra + line.chars().count() > max_chars
        {
            batches.push(std::mem::take(&mut current));
        }
        if !current.is_empty() {
            current.push('\n');
        }
        current.push_str(line);
    }
    if !current.is_empty() {
        batches.push(current);
    }
    batches
}

async fn google_request(
    client: &reqwest::Client,
    url: &str,
    webapp: bool,
    text: &str,
    src: &str,
    dst: &str,
) -> Result<String, String> {
    let mut delay = Duration::from_secs(2);
    let mut last_error = String::new();
    for attempt in 0..3 {
        let mut request = client
            .get(url)
            .header("user-agent", browser_user_agent())
            .header("accept", "application/json,text/plain,*/*")
            .query(&[("sl", src), ("tl", dst), ("dt", "t"), ("q", text)]);
        if webapp {
            let token = google_token(text);
            request = request.query(&[
                ("client", "webapp"),
                ("hl", "en"),
                ("v", "1.0"),
                ("source", "is"),
                ("tk", token.as_str()),
                ("dj", "1"),
                ("ie", "UTF-8"),
                ("oe", "UTF-8"),
            ]);
        } else {
            request = request.query(&[("client", "gtx"), ("ie", "UTF-8"), ("oe", "UTF-8")]);
        }
        let resp = request
            .send()
            .await
            .map_err(|e| format!("Google 翻译请求失败: {e}"))?;
        let status = resp.status();
        let retry_after = resp
            .headers()
            .get(reqwest::header::RETRY_AFTER)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.parse::<u64>().ok());
        let body = resp
            .text()
            .await
            .map_err(|e| format!("读取 Google 响应失败: {e}"))?;
        if status.is_success() {
            return if webapp {
                parse_google_webapp(&body)
            } else {
                parse_google(&body)
            };
        }
        last_error = format!("Google 翻译 HTTP {}: {}", status.as_u16(), preview(&body));
        if status.as_u16() != 429 || attempt == 2 {
            break;
        }
        tokio::time::sleep(Duration::from_secs(retry_after.unwrap_or(delay.as_secs()))).await;
        delay *= 2;
    }
    Err(last_error)
}

fn google_token(text: &str) -> String {
    let mut value: i64 = 406_644;
    // encodeURIComponent/unescape in the web client iterates UTF-8 bytes.
    for byte in text.as_bytes() {
        value = google_shift(value + i64::from(*byte), "+-a^+6");
        value = google_shift(value, "+-3^+b+-f");
    }
    value = js_i32(value ^ 3_293_161_072);
    if value < 0 {
        value = (value & 2_147_483_647) + 2_147_483_648;
    }
    value %= 1_000_000;
    format!("{value}.{}", js_i32(value ^ 3_293_161_072))
}

fn google_shift(mut value: i64, pattern: &str) -> i64 {
    let chars = pattern.as_bytes();
    let mut index = 0;
    while index + 2 < chars.len() {
        let mut shift = i64::from(chars[index + 2]);
        if shift >= i64::from(b'a') {
            shift -= 87;
        }
        let shifted = if chars[index + 1] == b'+' {
            js_i32(value) >> shift
        } else {
            js_i32(value) << shift
        };
        value = if chars[index] == b'+' {
            value + shifted
        } else {
            value ^ shifted
        };
        value = js_i32(value);
        index += 3;
    }
    value
}

fn js_i32(value: i64) -> i64 {
    let unsigned = value.rem_euclid(4_294_967_296);
    if unsigned >= 2_147_483_648 {
        unsigned - 4_294_967_296
    } else {
        unsigned
    }
}

fn parse_google(body: &str) -> Result<String, String> {
    let v: serde_json::Value =
        serde_json::from_str(body).map_err(|e| format!("Google 响应解析失败: {e}"))?;
    let segments = v[0]
        .as_array()
        .ok_or_else(|| "Google 响应结构异常".to_string())?;
    let mut out = String::new();
    for seg in segments {
        if let Some(t) = seg[0].as_str() {
            out.push_str(t);
        }
    }
    if out.trim().is_empty() {
        return Err("Google 翻译结果为空".to_string());
    }
    Ok(out)
}

fn parse_google_webapp(body: &str) -> Result<String, String> {
    let value: serde_json::Value =
        serde_json::from_str(body).map_err(|e| format!("Google 响应解析失败: {e}"))?;
    if let Some(sentences) = value["sentences"].as_array() {
        let output = sentences
            .iter()
            .filter_map(|sentence| sentence["trans"].as_str())
            .collect::<String>();
        if !output.trim().is_empty() {
            return Ok(output);
        }
    }
    parse_google(body)
}

/// DeepL 免费版接口（api-free.deepl.com/v2/translate，需免费注册的 auth_key）。
#[flutter_rust_bridge::frb]
pub async fn api_translate_deepl(
    text: String,
    src: String,
    dst: String,
    api_key: String,
) -> Result<String, String> {
    let key = api_key.trim();
    if key.is_empty() {
        return Err("请先在设置中填写 DeepL 免费版 API Key".to_string());
    }
    if text.trim().is_empty() {
        return Ok(String::new());
    }
    let client = http_client()?;
    let resp = client
        .post("https://api-free.deepl.com/v2/translate")
        .header("authorization", format!("DeepL-Auth-Key {key}"))
        .form(&[
            ("text", text.as_str()),
            ("source_lang", deepl_lang(&src).as_str()),
            ("target_lang", deepl_lang(&dst).as_str()),
        ])
        .send()
        .await
        .map_err(|e| format!("DeepL 请求失败: {e}"))?;
    let status = resp.status();
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        return Err(format!("DeepL HTTP {}: {}", status.as_u16(), preview(&body)));
    }
    let v: serde_json::Value =
        serde_json::from_str(&body).map_err(|e| format!("DeepL 响应解析失败: {e}"))?;
    let text_out = v["translations"][0]["text"]
        .as_str()
        .ok_or_else(|| "DeepL 响应中未找到翻译结果".to_string())?;
    Ok(text_out.trim().to_string())
}

fn deepl_lang(code: &str) -> String {
    let up = code.trim().to_ascii_uppercase();
    match up.as_str() {
        "ZH-CN" => "ZH".to_string(),
        "ZH-TW" | "ZH-HANT" => "ZH-HANT".to_string(),
        other => other.to_string(),
    }
}

/// Microsoft 免费翻译（Bing 网页端接口，无需 Key）。
/// Edge 的匿名 token 接口已下线，因此从 Bing 翻译页取得短期 token 后调用其页面接口。
#[flutter_rust_bridge::frb]
pub async fn api_translate_microsoft(
    text: String,
    src: String,
    dst: String,
) -> Result<String, String> {
    if text.trim().is_empty() {
        return Ok(String::new());
    }
    let client = http_client()?;
    let bing = fetch_bing_translation_config(&client).await?;
    let resp = client
        .post(bing.endpoint)
        .header("user-agent", browser_user_agent())
        .header("origin", bing.origin)
        .header("referer", bing.referer)
        .form(&[
            ("text", text.as_str()),
            ("fromLang", microsoft_lang(&src).as_str()),
            ("to", microsoft_lang(&dst).as_str()),
            ("token", bing.token.as_str()),
            ("key", bing.key.as_str()),
        ])
        .send()
        .await
        .map_err(|e| format!("微软翻译请求失败: {e}"))?;
    let status = resp.status();
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        return Err(format!("微软翻译 HTTP {}: {}", status.as_u16(), preview(&body)));
    }
    let v: serde_json::Value =
        serde_json::from_str(&body).map_err(|e| format!("微软响应解析失败: {e}"))?;
    let out = v[0]["translations"][0]["text"]
        .as_str()
        // Bing page API uses this compact shape, while the former Azure-style
        // endpoint returned translations[0].text.
        .or_else(|| v[0]["text"].as_str())
        .ok_or_else(|| "微软响应中未找到翻译结果".to_string())?;
    Ok(out.trim().to_string())
}

const BING_TRANSLATOR_URL: &str = "https://www.bing.com/translator";

struct BingTranslationConfig {
    endpoint: String,
    origin: String,
    referer: String,
    key: String,
    token: String,
}

fn browser_user_agent() -> &'static str {
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36 Edg/126.0"
}

async fn fetch_bing_translation_config(
    client: &reqwest::Client,
) -> Result<BingTranslationConfig, String> {
    let resp = client
        .get(BING_TRANSLATOR_URL)
        .header("user-agent", browser_user_agent())
        .header("accept-language", "zh-CN,zh;q=0.9,en;q=0.8")
        .send()
        .await
        .map_err(|e| format!("微软翻译页面请求失败: {e}"))?;
    let status = resp.status();
    let page_url = resp.url().clone();
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取微软翻译页面失败: {e}"))?;
    if !status.is_success() {
        return Err(format!(
            "微软翻译页面请求失败（HTTP {}）：请检查网络或代理设置",
            status.as_u16()
        ));
    }
    let (key, token) = parse_bing_auth(&body)?;
    let ig = parse_bing_ig(&body)?;
    let origin = page_url.origin().ascii_serialization();
    if origin == "null" {
        return Err("微软翻译页面地址异常".to_string());
    }
    Ok(BingTranslationConfig {
        endpoint: format!("{origin}/ttranslatev3?isVertical=1&IG={ig}&IID=translator.5028.1"),
        origin,
        referer: page_url.to_string(),
        key,
        token,
    })
}

fn parse_bing_auth(page: &str) -> Result<(String, String), String> {
    let marker = "params_AbusePreventionHelper";
    let start = page
        .find(marker)
        .and_then(|position| page[position..].find('[').map(|offset| position + offset + 1))
        .ok_or_else(|| "微软翻译页面缺少授权参数".to_string())?;
    let end = page[start..]
        .find(']')
        .map(|offset| start + offset)
        .ok_or_else(|| "微软翻译授权参数格式异常".to_string())?;
    let fields = page[start..end].split(',').map(str::trim).collect::<Vec<_>>();
    let key = fields
        .first()
        .filter(|value| value.chars().all(|c| c.is_ascii_digit()))
        .ok_or_else(|| "微软翻译授权密钥异常".to_string())?;
    let token = fields
        .get(1)
        .and_then(|value| value.strip_prefix('"'))
        .and_then(|value| value.strip_suffix('"'))
        .filter(|value| !value.is_empty())
        .ok_or_else(|| "微软翻译授权令牌异常".to_string())?;
    Ok(((*key).to_string(), token.to_string()))
}

fn parse_bing_ig(page: &str) -> Result<String, String> {
    let marker = "IG:\"";
    let start = page
        .find(marker)
        .map(|position| position + marker.len())
        .ok_or_else(|| "微软翻译页面缺少会话标识".to_string())?;
    let end = page[start..]
        .find('"')
        .map(|offset| start + offset)
        .ok_or_else(|| "微软翻译会话标识格式异常".to_string())?;
    let ig = &page[start..end];
    if ig.is_empty() || !ig.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err("微软翻译会话标识异常".to_string());
    }
    Ok(ig.to_string())
}

fn microsoft_lang(code: &str) -> String {
    match code.trim().to_ascii_lowercase().as_str() {
        "zh-cn" | "zh" => "zh-Hans".to_string(),
        "zh-tw" | "zh-hant" => "zh-Hant".to_string(),
        other => other.to_string(),
    }
}

/// 测试连接：GET {base}/models，校验 key 是否有效。
#[flutter_rust_bridge::frb]
pub async fn api_translate_test(
    base_url: String,
    model: String,
    api_key: String,
) -> Result<String, String> {
    let base = normalize_base(&base_url);
    if base.is_empty() {
        return Err("请先填写 API 地址".to_string());
    }
    let client = http_client()?;
    let mut req = client.get(format!("{base}/models"));
    let key = api_key.trim();
    if !key.is_empty() {
        req = req.header("authorization", format!("Bearer {key}"));
    }
    let resp = req
        .send()
        .await
        .map_err(|e| format!("连接失败: {e}"))?;
    let status = resp.status();
    if !status.is_success() {
        return Err(format!("HTTP {}：请检查地址或密钥", status.as_u16()));
    }
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    let v: serde_json::Value = serde_json::from_str(&body).unwrap_or(serde_json::Value::Null);
    let n = v["data"].as_array().map(|a| a.len()).unwrap_or(0);
    let model_note = if model.trim().is_empty() {
        String::new()
    } else {
        format!("，模型「{}」", model.trim())
    };
    Ok(format!("连接正常（{n} 个模型{model_note}）"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_completion_ok() {
        let body = r#"{"choices":[{"message":{"content":"你好\n世界"}}]}"#;
        assert_eq!(parse_completion(body).unwrap(), "你好\n世界");
    }

    #[test]
    fn parse_completion_strips_thinking() {
        let body = r#"{"choices":[{"message":{"reasoning_content":"ignored","content":"<think>reasoning</think>你好"}}]}"#;
        assert_eq!(parse_completion(body).unwrap(), "你好");
    }

    #[test]
    fn extracts_target_prefix_without_leaking_it_into_the_title() {
        assert_eq!(
            split_translation_target("[[KIKOETA_TARGET:zh-CN]]\n作品标题\n曲目".to_string()),
            ("zh-CN".to_string(), "作品标题\n曲目".to_string())
        );
        assert_eq!(
            split_translation_target("[[KIKOETA_TARGET:en]]\r\nWork title".to_string()),
            ("en".to_string(), "Work title".to_string())
        );
    }

    #[test]
    fn unpacks_indexed_translation_without_shifting_empty_lines() {
        let content = "[[KIKOETA_LINE_0]]标题\n[[KIKOETA_LINE_2]]曲目";
        assert_eq!(
            unpack_indexed_translation(content, 3).unwrap(),
            "标题\n\n曲目"
        );
    }

    #[test]
    fn unpacks_translation_when_marker_and_text_are_on_separate_lines() {
        let content = "[[KIKOETA_LINE_0]]\n作品标题\n[[KIKOETA_LINE_1]]\n第一首\n[[KIKOETA_LINE_2]]\n第二首";
        assert_eq!(
            unpack_indexed_translation(content, 3).unwrap(),
            "作品标题\n第一首\n第二首"
        );
    }

    #[test]
    fn rejects_unmarked_translation_with_wrong_line_count() {
        assert!(unpack_indexed_translation("作品标题\n第一首", 3).is_err());
    }

    #[test]
    fn configures_provider_specific_thinking_options() {
        let mut deepseek = serde_json::json!({});
        apply_thinking_options(
            &mut deepseek,
            "https://api.deepseek.com/v1",
            "deepseek-chat",
        );
        assert_eq!(deepseek["thinking"]["type"], "disabled");

        let mut qwen = serde_json::json!({});
        apply_thinking_options(
            &mut qwen,
            "https://api.siliconflow.cn/v1",
            "Qwen/Qwen3.5-4B",
        );
        assert_eq!(qwen["enable_thinking"], false);
    }

    #[test]
    fn parse_google_ok() {
        let body = r#"[[["你好","こんにちは",null,null,10]],null,"ja",null,null]"#;
        assert_eq!(parse_google(body).unwrap(), "你好");
    }

    #[test]
    fn parses_google_webapp_response() {
        let body = r#"{"sentences":[{"trans":"你好","orig":"こんにちは"}],"src":"ja"}"#;
        assert_eq!(parse_google_webapp(body).unwrap(), "你好");
    }

    #[test]
    fn computes_google_webapp_token() {
        assert_eq!(google_token("こんにちは"), "787929.-1002069079");
    }

    #[test]
    fn splits_google_requests_without_breaking_lines() {
        assert_eq!(
            google_batches("第一行\n第二行\n第三行", 5),
            vec!["第一行".to_string(), "第二行".to_string(), "第三行".to_string()]
        );
        assert_eq!(google_batches("短\n也短", 20), vec!["短\n也短".to_string()]);
    }

    #[test]
    fn deepl_lang_map() {
        assert_eq!(deepl_lang("zh-CN"), "ZH");
        assert_eq!(deepl_lang("zh-TW"), "ZH-HANT");
        assert_eq!(deepl_lang("ja"), "JA");
    }

    #[test]
    fn microsoft_lang_map() {
        assert_eq!(microsoft_lang("zh-CN"), "zh-Hans");
        assert_eq!(microsoft_lang("zh-TW"), "zh-Hant");
        assert_eq!(microsoft_lang("ja"), "ja");
    }

    #[test]
    fn parses_current_bing_page_authorization_values() {
        let page = r#"
            window._G={IG:"A1B2C3D4"};
            var params_AbusePreventionHelper = [1787866985732,"token-value",3600000];
        "#;
        assert_eq!(
            parse_bing_auth(page).unwrap(),
            ("1787866985732".to_string(), "token-value".to_string())
        );
        assert_eq!(parse_bing_ig(page).unwrap(), "A1B2C3D4");
    }

    #[test]
    fn rejects_invalid_bing_page_authorization_values() {
        assert!(parse_bing_auth("params_AbusePreventionHelper = []").is_err());
        assert!(parse_bing_ig("window._G={IG:\"not-a-session\"}").is_err());
    }
}
