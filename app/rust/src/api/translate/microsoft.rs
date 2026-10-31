use super::{browser_user_agent, preview};

// Bing's web UI and bing-translate-api use JavaScript string length (UTF-16).
// https://github.com/plainheart/bing-translate-api/blob/master/src/config.json
const MAX_TEXT_UNITS: usize = 1000;

pub(super) async fn translate(
    client: &reqwest::Client,
    text: &str,
    src: &str,
    dst: &str,
) -> Result<String, String> {
    translate_with_page(client, BING_TRANSLATOR_URL, text, src, dst).await
}

async fn translate_with_page(
    client: &reqwest::Client,
    page_url: &str,
    text: &str,
    src: &str,
    dst: &str,
) -> Result<String, String> {
    if text.trim().is_empty() {
        return Ok(String::new());
    }
    let source_lines = text
        .split('\n')
        .map(|line| line.trim_end_matches('\r'))
        .collect::<Vec<_>>();
    let nonempty = source_lines
        .iter()
        .copied()
        .filter(|line| !line.trim().is_empty())
        .collect::<Vec<_>>();
    let batches = batches(&nonempty)?;
    let bing = fetch_bing_translation_config(client, page_url).await?;
    let mut translated = Vec::with_capacity(nonempty.len());
    for batch in batches {
        let output = request(client, &bing, &batch, src, dst).await?;
        let count = batch.split('\n').count();
        if let Some(lines) = translation_lines(&output, count) {
            translated.extend(lines);
        } else {
            // LLM-backed responses can merge paragraphs. Retry individual titles
            // only when batching loses boundaries, so tracks cannot shift rows.
            for line in batch.split('\n') {
                let output = request(client, &bing, line, src, dst).await?;
                translated.push(output.lines().map(str::trim).collect::<Vec<_>>().join(" "));
            }
        }
    }
    let mut translated = translated.into_iter();
    Ok(source_lines
        .iter()
        .map(|line| {
            if line.trim().is_empty() {
                String::new()
            } else {
                translated.next().unwrap()
            }
        })
        .collect::<Vec<_>>()
        .join("\n"))
}

fn batches(lines: &[&str]) -> Result<Vec<String>, String> {
    let mut batches = Vec::new();
    let mut current = String::new();
    let mut units = 0;
    for line in lines {
        let length = line.encode_utf16().count();
        if length > MAX_TEXT_UNITS {
            return Err("单行标题超过微软翻译的 1000 字符限制".to_string());
        }
        let separator = usize::from(!current.is_empty());
        if units + separator + length > MAX_TEXT_UNITS {
            batches.push(std::mem::take(&mut current));
            units = 0;
        }
        if !current.is_empty() {
            current.push('\n');
            units += 1;
        }
        current.push_str(line);
        units += length;
    }
    if !current.is_empty() {
        batches.push(current);
    }
    Ok(batches)
}

fn translation_lines(output: &str, expected: usize) -> Option<Vec<String>> {
    let collect = |s: &str| {
        s.split('\n')
            .map(|line| line.trim().to_string())
            .collect::<Vec<_>>()
    };
    let mut lines = collect(output);
    if lines.len() != expected && expected > 1 {
        // Some current Bing LLM responses JSON-escape newlines twice.
        lines = collect(&output.replace("\\r\\n", "\n").replace("\\n", "\n"));
    }
    (lines.len() == expected && lines.iter().all(|line| !line.is_empty())).then_some(lines)
}

async fn request(
    client: &reqwest::Client,
    bing: &BingTranslationConfig,
    text: &str,
    src: &str,
    dst: &str,
) -> Result<String, String> {
    let resp = client
        .post(&bing.endpoint)
        .header("user-agent", browser_user_agent())
        .header("origin", &bing.origin)
        .header("referer", &bing.referer)
        .form(&[
            ("text", text),
            ("fromLang", microsoft_lang(src).as_str()),
            ("to", microsoft_lang(dst).as_str()),
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
        .map_err(|e| format!("读取微软翻译响应失败: {e}"))?;
    if !status.is_success() {
        return Err(format!(
            "微软翻译 HTTP {}: {}",
            status.as_u16(),
            preview(&body)
        ));
    }
    parse_response(&body)
}

fn parse_response(body: &str) -> Result<String, String> {
    let v: serde_json::Value =
        serde_json::from_str(body).map_err(|e| format!("微软响应解析失败: {e}"))?;
    if v["ShowCaptcha"].as_bool() == Some(true) {
        return Err("微软翻译要求验证码，请稍后重试或切换渠道".to_string());
    }
    if let Some(code) = v["statusCode"]
        .as_u64()
        .or_else(|| v["StatusCode"].as_u64())
        .filter(|code| *code >= 400)
    {
        if code == 401 || code == 429 {
            return Err(format!("微软翻译授权失效或请求受限（{code}），请稍后重试"));
        }
        let message = v["errorMessage"]
            .as_str()
            .filter(|message| !message.is_empty())
            .unwrap_or("请稍后重试或切换渠道");
        return Err(format!("微软翻译拒绝请求（{code}）：{}", preview(message)));
    }
    let output = v[0]["translations"][0]["text"]
        .as_str()
        .or_else(|| v[0]["text"].as_str())
        .filter(|output| !output.trim().is_empty())
        .ok_or_else(|| "微软响应中未找到翻译结果".to_string())?;
    Ok(output.trim().to_string())
}

const BING_TRANSLATOR_URL: &str = "https://www.bing.com/translator";

struct BingTranslationConfig {
    endpoint: String,
    origin: String,
    referer: String,
    key: String,
    token: String,
}

async fn fetch_bing_translation_config(
    client: &reqwest::Client,
    page_url: &str,
) -> Result<BingTranslationConfig, String> {
    let resp = client
        .get(page_url)
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
        .and_then(|position| {
            page[position..]
                .find('[')
                .map(|offset| position + offset + 1)
        })
        .ok_or_else(|| "微软翻译页面缺少授权参数".to_string())?;
    let end = page[start..]
        .find(']')
        .map(|offset| start + offset)
        .ok_or_else(|| "微软翻译授权参数格式异常".to_string())?;
    let fields = page[start..end]
        .split(',')
        .map(str::trim)
        .collect::<Vec<_>>();
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn batches_respect_bing_utf16_limit_and_title_boundaries() {
        let first = "あ".repeat(499);
        let second = "😀".repeat(250);
        assert_eq!(
            batches(&[&first, &second]).unwrap(),
            vec![format!("{first}\n{second}")]
        );
        let first = "あ".repeat(500);
        assert_eq!(batches(&[&first, &second]).unwrap(), vec![first, second]);
        assert!(batches(&[&"😀".repeat(501)]).is_err());
    }

    #[test]
    fn recognizes_errors_inside_successful_http_responses() {
        let error = parse_response(r#"{"statusCode":400,"errorMessage":""}"#).unwrap_err();
        assert!(error.contains("400"), "{error}");
        assert!(parse_response(r#"{"StatusCode":401}"#)
            .unwrap_err()
            .contains("请求受限"));
        assert!(parse_response(r#"{"ShowCaptcha":true}"#)
            .unwrap_err()
            .contains("验证码"));
        assert!(parse_response(r#"[{"translations":[{"text":" "}]}]"#).is_err());
        assert_eq!(parse_response(r#"[{"text":"你好"}]"#).unwrap(), "你好");
    }

    #[test]
    fn restores_double_escaped_line_breaks_only_when_needed() {
        let output =
            parse_response(r#"[{"translations":[{"text":"你好\\n晚安"}],"usedLLM":true}]"#)
                .unwrap();
        assert_eq!(translation_lines(&output, 2).unwrap(), vec!["你好", "晚安"]);
        assert_eq!(
            translation_lines(r"literal\nname.mp3", 1).unwrap(),
            vec![r"literal\nname.mp3"]
        );
        assert_eq!(
            translation_lines("你好\r\n晚安", 2).unwrap(),
            vec!["你好", "晚安"]
        );
        assert!(translation_lines("合并后的译文", 2).is_none());
        assert!(translation_lines("你好\n\n晚安", 2).is_none());
    }

    fn page() -> String {
        r#"window._G={IG:"A1B2C3D4"};var params_AbusePreventionHelper=[123,"token",3600000];"#
            .to_string()
    }

    #[test]
    fn long_requests_split_without_losing_blank_rows() {
        let server = crate::api::http_client::test_support::TestServer::new(|target| {
            if target == "/translator" {
                page()
            } else {
                r#"[{"translations":[{"text":"译文"}]}]"#.to_string()
            }
        });
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let text = format!("{}\r\n\r\n{}\r\n", "あ".repeat(600), "い".repeat(600));
        let output = runtime
            .block_on(translate_with_page(
                &reqwest::Client::builder().no_proxy().build().unwrap(),
                &format!("{}/translator", server.base),
                &text,
                "ja",
                "zh-CN",
            ))
            .unwrap();
        assert_eq!(output, "译文\n\n译文\n");
        assert_eq!(server.records().len(), 3); // one page, two bounded batches
    }

    #[test]
    fn merged_batch_retries_titles_individually_in_order() {
        let translation_requests = std::cell::Cell::new(0);
        let server = crate::api::http_client::test_support::TestServer::new(move |target| {
            if target == "/translator" {
                return page();
            }
            translation_requests.set(translation_requests.get() + 1);
            let text = match translation_requests.get() {
                1 => "合并的结果",
                2 => "你好",
                _ => "晚安",
            };
            serde_json::json!([{"translations": [{"text": text}]}]).to_string()
        });
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let output = runtime
            .block_on(translate_with_page(
                &reqwest::Client::builder().no_proxy().build().unwrap(),
                &format!("{}/translator", server.base),
                "こんにちは\nおやすみなさい",
                "ja",
                "zh-CN",
            ))
            .unwrap();
        assert_eq!(output, "你好\n晚安");
        assert_eq!(server.records().len(), 4);
    }

    #[test]
    #[ignore = "requires access to Bing Translator"]
    fn microsoft_live_translation() {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let client = super::super::http_client().unwrap();
            let text = (1..=30).map(|index| format!("{index:02} おやすみなさい。今日はゆっくり休んで、明日また会いましょう。耳元で優しくささやきます。"))
                .collect::<Vec<_>>().join("\n");
            assert!(text.encode_utf16().count() > MAX_TEXT_UNITS);
            let output = translate(&client, &text, "ja", "zh-CN").await.unwrap();
            assert_eq!(output.split('\n').count(), 30, "{output}");
            assert!(output.contains('晚') || output.contains('休'), "{output}");
            println!("Bing live: {} UTF-16 units, {} input/output rows", text.encode_utf16().count(), output.split('\n').count());
            println!("{}", output.lines().take(2).collect::<Vec<_>>().join("\n"));
        });
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
