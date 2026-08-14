//! 文本编码检测与解码：自动检测（BOM / UTF-8 严格校验 / chardetng 猜测），
//! 也支持手动指定编码。覆盖中日英常用编码（UTF-8、UTF-16、GB18030/GBK、
//! Big5、Shift_JIS、EUC-JP、ISO-2022-JP、Windows-1252）。

use chardetng::EncodingDetector;
use encoding_rs::Encoding;

#[derive(Debug)]
pub struct DecodedText {
    pub encoding: String,
    pub text: String,
}

/// 解码文本。`encoding` 为空时自动检测；否则按指定编码解码。
#[flutter_rust_bridge::frb(sync)]
pub fn api_decode_text(bytes: Vec<u8>, encoding: String) -> Result<DecodedText, String> {
    let label = encoding.trim();
    if label.is_empty() {
        return Ok(auto_decode(&bytes));
    }
    decode_with(&bytes, label)
}

fn auto_decode(bytes: &[u8]) -> DecodedText {
    // BOM 优先
    if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
        return DecodedText {
            encoding: "UTF-8".into(),
            text: String::from_utf8_lossy(&bytes[3..]).into_owned(),
        };
    }
    if bytes.starts_with(&[0xFF, 0xFE]) {
        return DecodedText {
            encoding: "UTF-16LE".into(),
            text: decode_utf16(&bytes[2..], true),
        };
    }
    if bytes.starts_with(&[0xFE, 0xFF]) {
        return DecodedText {
            encoding: "UTF-16BE".into(),
            text: decode_utf16(&bytes[2..], false),
        };
    }
    // ISO-2022-JP 靠 ESC 转义序列切换字符集，chardetng 难以识别，先按特征判断
    if has_iso2022jp_marker(bytes) {
        if let Some(t) = strict_decode(bytes, "iso-2022-jp") {
            return DecodedText {
                encoding: "ISO-2022-JP".into(),
                text: t,
            };
        }
    }
    // 严格 UTF-8 合法则直接按 UTF-8 处理（纯 ASCII 也走这里）
    if std::str::from_utf8(bytes).is_ok() {
        return DecodedText {
            encoding: "UTF-8".into(),
            text: String::from_utf8_lossy(bytes).into_owned(),
        };
    }
    // chardetng（Firefox 同款检测器）猜测
    let mut det = EncodingDetector::new();
    det.feed(bytes, true);
    let enc = det.guess(None, true);
    let (text, _, had_errors) = enc.decode(bytes);
    if !had_errors {
        return DecodedText {
            encoding: enc.name().to_string(),
            text: text.into_owned(),
        };
    }
    // 猜测有错误时，按常见编码严格尝试
    for label in ["gb18030", "shift_jis", "big5", "euc-jp", "iso-2022-jp", "windows-1252"] {
        if let Some(t) = strict_decode(bytes, label) {
            return DecodedText {
                encoding: label.to_string(),
                text: t,
            };
        }
    }
    DecodedText {
        encoding: enc.name().to_string(),
        text: text.into_owned(),
    }
}

fn decode_with(bytes: &[u8], label: &str) -> Result<DecodedText, String> {
    let upper = label.to_ascii_uppercase().replace('_', "-");
    match upper.as_str() {
        "UTF-8" => {
            let b = bytes.strip_prefix(&[0xEF, 0xBB, 0xBF]).unwrap_or(bytes);
            Ok(DecodedText {
                encoding: "UTF-8".into(),
                text: String::from_utf8_lossy(b).into_owned(),
            })
        }
        "UTF-16LE" | "UTF-16" => {
            let b = bytes.strip_prefix(&[0xFF, 0xFE]).unwrap_or(bytes);
            Ok(DecodedText {
                encoding: "UTF-16LE".into(),
                text: decode_utf16(b, true),
            })
        }
        "UTF-16BE" => {
            let b = bytes.strip_prefix(&[0xFE, 0xFF]).unwrap_or(bytes);
            Ok(DecodedText {
                encoding: "UTF-16BE".into(),
                text: decode_utf16(b, false),
            })
        }
        _ => {
            let enc = Encoding::for_label(label.as_bytes()).ok_or_else(|| "未知编码".to_string())?;
            let (text, _, _) = enc.decode(bytes);
            Ok(DecodedText {
                encoding: enc.name().to_string(),
                text: text.into_owned(),
            })
        }
    }
}

fn strict_decode(bytes: &[u8], label: &str) -> Option<String> {
    let enc = Encoding::for_label(label.as_bytes())?;
    enc.decode_without_bom_handling_and_without_replacement(bytes)
        .map(|c| c.into_owned())
}

fn has_iso2022jp_marker(bytes: &[u8]) -> bool {
    bytes
        .windows(2)
        .any(|w| w[0] == 0x1B && (w[1] == b'$' || w[1] == b'(' || w[1] == b')'))
}

fn decode_utf16(bytes: &[u8], little: bool) -> String {
    let units: Vec<u16> = bytes
        .chunks_exact(2)
        .map(|c| {
            if little {
                u16::from_le_bytes([c[0], c[1]])
            } else {
                u16::from_be_bytes([c[0], c[1]])
            }
        })
        .collect();
    String::from_utf16_lossy(&units)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn encode(label: &str, text: &str) -> Vec<u8> {
        let enc = Encoding::for_label(label.as_bytes()).unwrap();
        let (bytes, _, _) = enc.encode(text);
        bytes.into_owned()
    }

    #[test]
    fn roundtrip_common_encodings() {
        let cases = [
            ("GBK", "简体中文测试，你好世界"),
            ("big5", "繁體中文測試，你好世界"),
            ("shift_jis", "日本語のテスト、こんにちは"),
            ("euc-jp", "日本語のテスト、こんにちは"),
            ("iso-2022-jp", "日本語のテスト"),
            ("windows-1252", "Hello, ASCII and café"),
        ];
        for (label, sample) in cases {
            let bytes = encode(label, sample);
            let got = auto_decode(&bytes);
            assert_eq!(got.text, sample, "自动检测 {label} 解码结果不一致");
        }
    }

    #[test]
    fn utf8_and_bom() {
        let plain = auto_decode("纯 UTF-8 内容".as_bytes());
        assert_eq!(plain.text, "纯 UTF-8 内容");
        assert_eq!(plain.encoding, "UTF-8");

        let mut utf16le = vec![0xFF, 0xFE];
        for u in "UTF-16 内容".encode_utf16() {
            utf16le.extend_from_slice(&u.to_le_bytes());
        }
        let got = auto_decode(&utf16le);
        assert_eq!(got.text, "UTF-16 内容");
        assert_eq!(got.encoding, "UTF-16LE");
    }

    #[test]
    fn manual_labels() {
        let bytes = encode("shift_jis", "手動指定エンコーディング");
        let got = decode_with(&bytes, "Shift_JIS").unwrap();
        assert_eq!(got.text, "手動指定エンコーディング");
        // 手动指定错误编码时不应崩溃（结果允许乱码，但函数应成功）
        let _ = decode_with(&bytes, "GBK").unwrap();
    }
}
