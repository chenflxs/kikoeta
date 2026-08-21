//! 歌词繁简转换。
//!
//! 所有平台均使用内嵌的 OpenCC 兼容词典，Windows 与 Android 共享完整的
//! 字符与词组转换行为。

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use zhhz::{Config, Converter};

static CACHE: OnceLock<Mutex<HashMap<(String, String), String>>> = OnceLock::new();
static S2T_CONVERTER: OnceLock<Mutex<Converter>> = OnceLock::new();
static T2S_CONVERTER: OnceLock<Mutex<Converter>> = OnceLock::new();

fn cache() -> &'static Mutex<HashMap<(String, String), String>> {
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// 繁简转换。mode: `s2t`（简→繁）/ `t2s`（繁→简）/ `auto`（自动检测）。
#[flutter_rust_bridge::frb(sync)]
pub fn api_convert_text(text: String, mode: String) -> Result<String, String> {
    if !matches!(mode.as_str(), "s2t" | "t2s" | "auto") {
        return Err(format!("未知转换模式: {mode}"));
    }

    let key = (mode.clone(), text.clone());
    if let Some(hit) = cache().lock().ok().and_then(|cache| cache.get(&key).cloned()) {
        return Ok(hit);
    }
    if text.is_empty() {
        return Ok(String::new());
    }

    let direction = if mode == "auto" {
        detect_direction(&text)
    } else {
        mode.as_str()
    };
    let converted = match direction {
        "s2t" => convert_s2t(&text),
        _ => convert_t2s(&text),
    };

    if let Ok(mut cache) = cache().lock() {
        cache.insert(key, converted.clone());
        if cache.len() > 512 {
            cache.clear();
        }
    }
    Ok(converted)
}

fn detect_direction(text: &str) -> &'static str {
    let s2t = convert_s2t(text);
    let t2s = convert_t2s(text);
    let simplified_changes = change_score(text, &s2t);
    let traditional_changes = change_score(text, &t2s);

    if traditional_changes > simplified_changes {
        "t2s"
    } else {
        "s2t"
    }
}

fn change_score(original: &str, converted: &str) -> usize {
    original
        .chars()
        .zip(converted.chars())
        .filter(|(before, after)| before != after)
        .count()
        + original.chars().count().abs_diff(converted.chars().count())
}

fn convert_s2t(text: &str) -> String {
    S2T_CONVERTER
        .get_or_init(|| Mutex::new(Converter::new(Config::S2t)))
        .lock()
        .map(|converter| converter.convert(text))
        .unwrap_or_else(|_| Converter::new(Config::S2t).convert(text))
}

fn convert_t2s(text: &str) -> String {
    T2S_CONVERTER
        .get_or_init(|| Mutex::new(Converter::new(Config::T2s)))
        .lock()
        .map(|converter| converter.convert(text))
        .unwrap_or_else(|_| Converter::new(Config::T2s).convert(text))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn s2t_basic() {
        assert_eq!(api_convert_text("头发".into(), "s2t".into()).unwrap(), "頭髮");
        assert_eq!(
            api_convert_text("我喜欢听音乐".into(), "s2t".into()).unwrap(),
            "我喜歡聽音樂"
        );
    }

    #[test]
    fn t2s_basic() {
        assert_eq!(api_convert_text("頭髮".into(), "t2s".into()).unwrap(), "头发");
        assert_eq!(
            api_convert_text("我喜歡聽音樂".into(), "t2s".into()).unwrap(),
            "我喜欢听音乐"
        );
    }

    #[test]
    fn t2s_converts_extended_opencc_characters() {
        assert_eq!(
            api_convert_text("繁體字轉換測試：鑰匙、麵條、檯燈、週末".into(), "t2s".into())
                .unwrap(),
            "繁体字转换测试：钥匙、面条、台灯、周末"
        );
    }

    #[test]
    fn auto_detects_extended_traditional_characters() {
        assert_eq!(
            api_convert_text("鑰匙、麵條、檯燈、週末".into(), "auto".into()).unwrap(),
            "钥匙、面条、台灯、周末"
        );
    }

    #[test]
    fn auto_direction() {
        assert_eq!(
            api_convert_text("我喜欢听音乐".into(), "auto".into()).unwrap(),
            "我喜歡聽音樂"
        );
        assert_eq!(
            api_convert_text("我喜歡聽音樂".into(), "auto".into()).unwrap(),
            "我喜欢听音乐"
        );
    }

    #[test]
    fn fallback_roundtrip() {
        let simplified = "大家一起来听音乐吧";
        let traditional = convert_s2t(simplified);
        assert_eq!(convert_t2s(&traditional), simplified);
    }
}
