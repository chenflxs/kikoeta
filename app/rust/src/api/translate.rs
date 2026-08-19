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

/// Google 免费翻译接口（translate.googleapis.com gtx，无需 Key）。
/// 作用范围与 OpenAI 一致：多行标题拼接翻译，保持行数。
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
    let url = "https://translate.googleapis.com/translate_a/single";
    let resp = client
        .get(url)
        .query(&[
            ("client", "gtx"),
            ("sl", src.as_str()),
            ("tl", dst.as_str()),
            ("dt", "t"),
            ("q", text.as_str()),
        ])
        .send()
        .await
        .map_err(|e| format!("Google 翻译请求失败: {e}"))?;
    let status = resp.status();
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取响应失败: {e}"))?;
    if !status.is_success() {
        return Err(format!("Google 翻译 HTTP {}: {}", status.as_u16(), preview(&body)));
    }
    parse_google(&body)
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
        .form(&[
            ("auth_key", key),
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

/// Microsoft 免费翻译（Edge 浏览器同款接口，无需 Key）：
/// 先从 edge.microsoft.com 取匿名 token，再调 api-edge 翻译。
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
    let token = fetch_edge_token(&client).await?;
    let url = format!(
        "https://api-edge.cognitive.microsofttranslator.com/translate?api-version=3.0&from={}&to={}",
        microsoft_lang(&src),
        microsoft_lang(&dst)
    );
    let body = serde_json::json!([{ "Text": text }]);
    let resp = client
        .post(&url)
        .header("authorization", format!("Bearer {token}"))
        .header("content-type", "application/json")
        .body(body.to_string())
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
        .ok_or_else(|| "微软响应中未找到翻译结果".to_string())?;
    Ok(out.trim().to_string())
}

async fn fetch_edge_token(client: &reqwest::Client) -> Result<String, String> {
    let resp = client
        .get("https://edge.microsoft.com/translate/auth")
        .header("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36 Edg/126.0")
        .send()
        .await
        .map_err(|e| format!("微软授权接口请求失败: {e}"))?;
    let status = resp.status();
    let body = resp
        .text()
        .await
        .map_err(|e| format!("读取授权响应失败: {e}"))?;
    if !status.is_success() {
        return Err(format!(
            "微软免费翻译授权失败（HTTP {}）——edge.microsoft.com 可能被当前网络拦截，可改用 Google/DeepL/OpenAI 引擎",
            status.as_u16()
        ));
    }
    let token = body.trim().to_string();
    if token.is_empty() || token.len() < 20 {
        return Err("微软授权响应异常".to_string());
    }
    Ok(token)
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
}
