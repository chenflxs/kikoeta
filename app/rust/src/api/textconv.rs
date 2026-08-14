//! 歌词繁简转换。
//!
//! - 词组表优先（处理 头发→頭髮、后面→後面 等词级差异）；
//! - 剩余字符：Windows 用系统 `LCMapStringEx` 全覆盖，其他平台用内置字表兜底。
//! - `auto` 模式：按简/繁特征字比例判定方向。

use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::OnceLock;

static CACHE: OnceLock<Mutex<HashMap<(String, String), String>>> = OnceLock::new();

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
    if let Some(hit) = cache().lock().ok().and_then(|c| c.get(&key).cloned()) {
        return Ok(hit);
    }
    if text.is_empty() {
        return Ok(String::new());
    }
    let dir = if mode == "auto" {
        detect_direction(&text)
    } else {
        mode.as_str()
    };
    let out = match dir {
        "s2t" => convert_s2t(&text),
        _ => convert_t2s(&text),
    };
    if let Ok(mut c) = cache().lock() {
        c.insert(key, out.clone());
        if c.len() > 512 {
            c.clear();
        }
    }
    Ok(out)
}

fn detect_direction(text: &str) -> &'static str {
    let s2t = s2t_map();
    let t2s = t2s_map();
    let mut sim = 0usize;
    let mut trad = 0usize;
    for ch in text.chars() {
        if s2t.contains_key(&ch) {
            sim += 1;
        }
        if t2s.contains_key(&ch) {
            trad += 1;
        }
    }
    if trad > sim {
        "t2s"
    } else {
        "s2t"
    }
}

// ---------------- Windows：系统词级转换 ----------------

#[cfg(target_os = "windows")]
mod win {
    use std::ffi::c_void;

    #[link(name = "Kernel32")]
    unsafe extern "system" {
        fn LCMapStringEx(
            lp_locale_name: *const u16,
            dw_map_flags: u32,
            lp_src_str: *const u16,
            cch_src: i32,
            lp_dest_str: *mut u16,
            cch_dest: i32,
            lp_version_information: *const c_void,
            lp_reserved: *const c_void,
            l_param: isize,
        ) -> i32;
    }

    const LCMAP_TRADITIONAL_CHINESE: u32 = 0x0400_0000;
    const LCMAP_SIMPLIFIED_CHINESE: u32 = 0x0200_0000;
    // LOCALE_NAME_SYSTEM = L"!x-sys-default-locale"
    const LOCALE_SYSTEM: &[u16] = &[
        '!' as u16, 'x' as u16, '-' as u16, 's' as u16, 'y' as u16, 's' as u16, '-' as u16,
        'd' as u16, 'e' as u16, 'f' as u16, 'a' as u16, 'u' as u16, 'l' as u16, 't' as u16,
        '-' as u16, 'l' as u16, 'o' as u16, 'c' as u16, 'a' as u16, 'l' as u16, 'e' as u16, 0,
    ];

    pub(super) fn map(text: &str, to_traditional: bool) -> Option<String> {
        let src: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
        let flags = if to_traditional {
            LCMAP_TRADITIONAL_CHINESE
        } else {
            LCMAP_SIMPLIFIED_CHINESE
        };
        unsafe {
            let n = LCMapStringEx(
                LOCALE_SYSTEM.as_ptr(),
                flags,
                src.as_ptr(),
                -1,
                std::ptr::null_mut(),
                0,
                std::ptr::null(),
                std::ptr::null(),
                0,
            );
            if n <= 0 {
                return None;
            }
            let mut dst = vec![0u16; n as usize];
            let written = LCMapStringEx(
                LOCALE_SYSTEM.as_ptr(),
                flags,
                src.as_ptr(),
                -1,
                dst.as_mut_ptr(),
                n,
                std::ptr::null(),
                std::ptr::null(),
                0,
            );
            if written <= 0 {
                return None;
            }
            let len = (written as usize).saturating_sub(1);
            Some(String::from_utf16_lossy(&dst[..len]))
        }
    }
}

fn convert_s2t(text: &str) -> String {
    apply_conversion(text, &S2T_WORD, true)
}

fn convert_t2s(text: &str) -> String {
    apply_conversion(text, &T2S_WORD, false)
}

/// 词组优先 + 字符级兜底（Windows 用系统 API，其他平台用内置字表）
fn apply_conversion(text: &str, words: &[(&str, &str)], to_traditional: bool) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    let mut run = String::new();
    while !rest.is_empty() {
        if let Some((to, next)) = words
            .iter()
            .find_map(|(f, t)| rest.starts_with(f).then(|| (*t, &rest[f.len()..])))
        {
            flush_run(&mut out, &mut run, to_traditional);
            out.push_str(to);
            rest = next;
            continue;
        }
        let mut chars = rest.chars();
        let c = chars.next().unwrap();
        run.push(c);
        rest = chars.as_str();
    }
    flush_run(&mut out, &mut run, to_traditional);
    out
}

fn flush_run(out: &mut String, run: &mut String, to_traditional: bool) {
    if run.is_empty() {
        return;
    }
    let s = std::mem::take(run);
    #[cfg(target_os = "windows")]
    if let Some(conv) = win::map(&s, to_traditional) {
        out.push_str(&conv);
        return;
    }
    let m = if to_traditional { s2t_map() } else { t2s_map() };
    for c in s.chars() {
        out.push(*m.get(&c).unwrap_or(&c));
    }
}

// ---------------- 内置映射表（非 Windows 兜底） ----------------

static S2T_WORD: &[(&str, &str)] = &[
    ("头发", "頭髮"),
    ("后面", "後面"),
    ("里面", "裡面"),
    ("什么", "什麼"),
    ("为什么", "為什麼"),
    ("时候", "時候"),
    ("喜欢", "喜歡"),
    ("睡觉", "睡覺"),
    ("声音", "聲音"),
    ("感觉", "感覺"),
    ("现在", "現在"),
    ("这里", "這裡"),
    ("那里", "那裡"),
    ("那个", "那個"),
    ("这个", "這個"),
    ("因为", "因為"),
    ("虽然", "雖然"),
    ("然后", "然後"),
    ("以后", "以後"),
    ("已经", "已經"),
    ("没有", "沒有"),
    ("还有", "還有"),
    ("还是", "還是"),
    ("当然", "當然"),
    ("继续", "繼續"),
    ("开始", "開始"),
    ("结束", "結束"),
    ("回来", "回來"),
    ("起来", "起來"),
    ("出来", "出來"),
    ("过去", "過去"),
    ("觉得", "覺得"),
    ("记得", "記得"),
    ("忘记", "忘記"),
    ("谢谢", "謝謝"),
    ("再见", "再見"),
    ("没关系", "沒關係"),
    ("对不起", "對不起"),
    ("听说", "聽說"),
    ("告诉", "告訴"),
    ("准备", "準備"),
    ("看见", "看見"),
    ("发现", "發現"),
    ("说话", "說話"),
    ("音乐", "音樂"),
    ("歌词", "歌詞"),
    ("简体", "簡體"),
    ("繁体", "繁體"),
    ("汉语", "漢語"),
    ("日语", "日語"),
    ("英语", "英語"),
    ("干净", "乾淨"),
    ("干活", "幹活"),
    ("台湾", "臺灣"),
    ("台风", "颱風"),
    ("干杯", "乾杯"),
    ("白云", "白雲"),
];

static T2S_WORD: &[(&str, &str)] = &[
    ("頭髮", "头发"),
    ("後面", "后面"),
    ("裡面", "里面"),
    ("什麼", "什么"),
    ("為什麼", "为什么"),
    ("時候", "时候"),
    ("喜歡", "喜欢"),
    ("睡覺", "睡觉"),
    ("聲音", "声音"),
    ("感覺", "感觉"),
    ("現在", "现在"),
    ("這裡", "这里"),
    ("那裡", "那里"),
    ("那個", "那个"),
    ("這個", "这个"),
    ("因為", "因为"),
    ("雖然", "虽然"),
    ("然後", "然后"),
    ("以後", "以后"),
    ("已經", "已经"),
    ("沒有", "没有"),
    ("還有", "还有"),
    ("還是", "还是"),
    ("當然", "当然"),
    ("繼續", "继续"),
    ("開始", "开始"),
    ("結束", "结束"),
    ("回來", "回来"),
    ("起來", "起来"),
    ("出來", "出来"),
    ("過去", "过去"),
    ("覺得", "觉得"),
    ("記得", "记得"),
    ("忘記", "忘记"),
    ("謝謝", "谢谢"),
    ("再見", "再见"),
    ("沒關係", "没关系"),
    ("對不起", "对不起"),
    ("聽說", "听说"),
    ("告訴", "告诉"),
    ("準備", "准备"),
    ("看見", "看见"),
    ("發現", "发现"),
    ("說話", "说话"),
    ("音樂", "音乐"),
    ("歌詞", "歌词"),
    ("簡體", "简体"),
    ("繁體", "繁体"),
    ("漢語", "汉语"),
    ("日語", "日语"),
    ("英語", "英语"),
    ("乾淨", "干净"),
    ("幹活", "干活"),
    ("臺灣", "台湾"),
    ("颱風", "台风"),
    ("乾杯", "干杯"),
    ("白雲", "白云"),
];

static S2T_CHAR_PAIRS: &[(char, char)] = &[
    ('门', '門'), ('们', '們'), ('说', '說'), ('请', '請'), ('听', '聽'),
    ('个', '個'), ('对', '對'), ('时', '時'), ('间', '間'), ('开', '開'),
    ('发', '發'), ('关', '關'), ('体', '體'), ('为', '為'), ('会', '會'),
    ('话', '話'), ('见', '見'), ('来', '來'), ('里', '裡'), ('头', '頭'),
    ('这', '這'), ('么', '麼'), ('点', '點'), ('应', '應'), ('帮', '幫'),
    ('欢', '歡'), ('语', '語'), ('译', '譯'), ('简', '簡'), ('声', '聲'),
    ('变', '變'), ('梦', '夢'), ('闭', '閉'), ('轻', '輕'), ('随', '隨'),
    ('爱', '愛'), ('万', '萬'), ('与', '與'), ('书', '書'), ('东', '東'),
    ('丝', '絲'), ('两', '兩'), ('义', '義'), ('乌', '烏'), ('乐', '樂'),
    ('买', '買'), ('习', '習'), ('亲', '親'), ('从', '從'), ('众', '眾'),
    ('传', '傳'), ('伤', '傷'), ('价', '價'), ('伦', '倫'), ('伟', '偉'),
    ('优', '優'), ('伞', '傘'), ('伪', '偽'), ('债', '債'), ('儿', '兒'),
    ('党', '黨'), ('兴', '興'), ('写', '寫'), ('军', '軍'), ('农', '農'),
    ('决', '決'), ('况', '況'), ('冻', '凍'), ('净', '淨'), ('几', '幾'),
    ('风', '風'), ('凯', '凱'), ('凤', '鳳'), ('凭', '憑'), ('击', '擊'),
    ('刘', '劉'), ('则', '則'), ('刚', '剛'), ('创', '創'), ('别', '別'),
    ('删', '刪'), ('办', '辦'), ('剑', '劍'), ('剂', '劑'), ('剧', '劇'),
    ('务', '務'), ('动', '動'), ('励', '勵'), ('劳', '勞'), ('势', '勢'),
    ('华', '華'), ('单', '單'), ('区', '區'), ('医', '醫'), ('却', '卻'),
    ('厂', '廠'), ('厅', '廳'), ('双', '雙'), ('观', '觀'), ('叶', '葉'),
    ('号', '號'), ('吗', '嗎'), ('吓', '嚇'), ('吕', '呂'), ('启', '啟'),
    ('吴', '吳'), ('员', '員'), ('呜', '嗚'), ('咏', '詠'), ('响', '響'),
    ('哒', '噠'), ('哑', '啞'), ('哗', '嘩'), ('哟', '喲'), ('圆', '圓'),
    ('团', '團'), ('国', '國'), ('图', '圖'), ('场', '場'), ('坏', '壞'),
    ('块', '塊'), ('坚', '堅'), ('处', '處'), ('备', '備'), ('够', '夠'),
    ('夺', '奪'), ('奋', '奮'), ('妇', '婦'), ('妈', '媽'), ('孙', '孫'),
    ('学', '學'), ('宁', '寧'), ('实', '實'), ('宝', '寶'), ('审', '審'),
    ('导', '導'), ('将', '將'), ('尔', '爾'), ('尝', '嘗'), ('层', '層'),
    ('岁', '歲'), ('岂', '豈'), ('岗', '崗'), ('岛', '島'), ('岭', '嶺'),
    ('师', '師'), ('带', '帶'), ('广', '廣'), ('库', '庫'), ('张', '張'),
    ('弥', '彌'), ('异', '異'), ('弃', '棄'), ('归', '歸'), ('录', '錄'),
    ('忆', '憶'), ('忧', '憂'), ('怀', '懷'), ('态', '態'), ('恒', '恆'),
    ('恶', '惡'), ('惧', '懼'), ('惊', '驚'), ('愿', '願'), ('戏', '戲'),
    ('战', '戰'), ('户', '戶'), ('扬', '揚'), ('护', '護'), ('报', '報'),
    ('担', '擔'), ('拟', '擬'), ('拥', '擁'), ('换', '換'), ('据', '據'),
    ('挂', '掛'), ('择', '擇'), ('挚', '摯'), ('摄', '攝'), ('数', '數'),
    ('断', '斷'), ('无', '無'), ('旧', '舊'), ('显', '顯'), ('晒', '曬'),
    ('术', '術'), ('机', '機'), ('杀', '殺'), ('杂', '雜'), ('权', '權'),
    ('条', '條'), ('极', '極'), ('构', '構'), ('标', '標'), ('样', '樣'),
    ('检', '檢'), ('楼', '樓'), ('桥', '橋'), ('气', '氣'), ('汉', '漢'),
    ('汤', '湯'), ('泪', '淚'), ('测', '測'), ('济', '濟'), ('浓', '濃'),
    ('涛', '濤'), ('润', '潤'), ('涨', '漲'), ('渐', '漸'), ('洁', '潔'),
    ('灭', '滅'), ('灯', '燈'), ('灾', '災'), ('炉', '爐'), ('热', '熱'),
    ('爷', '爺'), ('争', '爭'), ('状', '狀'), ('独', '獨'), ('狭', '狹'),
    ('猪', '豬'), ('献', '獻'), ('环', '環'), ('现', '現'), ('玛', '瑪'),
    ('电', '電'), ('画', '畫'), ('畅', '暢'), ('疗', '療'), ('疯', '瘋'),
    ('盐', '鹽'), ('监', '監'), ('盘', '盤'), ('矿', '礦'), ('码', '碼'),
    ('礼', '禮'), ('离', '離'), ('种', '種'), ('称', '稱'), ('积', '積'),
    ('穷', '窮'), ('窃', '竊'), ('竞', '競'), ('笔', '筆'), ('筹', '籌'),
    ('签', '簽'), ('类', '類'), ('约', '約'), ('红', '紅'), ('纯', '純'),
    ('纸', '紙'), ('线', '線'), ('练', '練'), ('组', '組'), ('细', '細'),
    ('终', '終'), ('经', '經'), ('结', '結'), ('绕', '繞'), ('绘', '繪'),
    ('给', '給'), ('绝', '絕'), ('统', '統'), ('继', '繼'), ('续', '續'),
    ('绳', '繩'), ('维', '維'), ('绿', '綠'), ('编', '編'), ('缘', '緣'),
    ('县', '縣'), ('紧', '緊'), ('网', '網'), ('罗', '羅'), ('罚', '罰'),
    ('联', '聯'), ('聪', '聰'), ('肠', '腸'), ('肤', '膚'), ('脸', '臉'),
    ('脱', '脫'), ('临', '臨'), ('举', '舉'), ('舰', '艦'), ('艰', '艱'),
    ('艺', '藝'), ('节', '節'), ('茧', '繭'), ('苍', '蒼'), ('苏', '蘇'),
    ('获', '獲'), ('萤', '螢'), ('虫', '蟲'), ('虽', '雖'), ('虾', '蝦'),
    ('蚁', '蟻'), ('蛮', '蠻'), ('觉', '覺'), ('记', '記'), ('讲', '講'),
    ('设', '設'), ('词', '詞'), ('询', '詢'), ('该', '該'), ('详', '詳'),
    ('误', '誤'), ('诸', '諸'), ('读', '讀'), ('课', '課'), ('谁', '誰'),
    ('调', '調'), ('谈', '談'), ('谊', '誼'), ('谋', '謀'), ('谢', '謝'),
    ('谦', '謙'), ('贝', '貝'), ('负', '負'), ('贡', '貢'), ('财', '財'),
    ('贤', '賢'), ('败', '敗'), ('货', '貨'), ('质', '質'), ('购', '購'),
    ('贴', '貼'), ('贵', '貴'), ('费', '費'), ('贺', '賀'), ('资', '資'),
    ('赋', '賦'), ('赏', '賞'), ('赔', '賠'), ('赖', '賴'), ('赚', '賺'),
    ('赛', '賽'), ('赠', '贈'), ('赵', '趙'), ('赶', '趕'), ('践', '踐'),
    ('车', '車'), ('转', '轉'), ('软', '軟'), ('轰', '轟'), ('较', '較'),
    ('载', '載'), ('辉', '輝'), ('轮', '輪'), ('输', '輸'), ('边', '邊'),
    ('达', '達'), ('迁', '遷'), ('过', '過'), ('进', '進'), ('远', '遠'),
    ('违', '違'), ('连', '連'), ('迟', '遲'), ('适', '適'), ('选', '選'),
    ('逊', '遜'), ('递', '遞'), ('逻', '邏'), ('遗', '遺'), ('还', '還'),
    ('邓', '鄧'), ('邮', '郵'), ('邻', '鄰'), ('郑', '鄭'), ('乡', '鄉'),
    ('着', '著'), ('脚', '腳'),
];

static S2T_CHAR: OnceLock<HashMap<char, char>> = OnceLock::new();
static T2S_CHAR: OnceLock<HashMap<char, char>> = OnceLock::new();

fn static_char_map() -> HashMap<char, char> {
    let mut m = HashMap::new();
    for (s, t) in S2T_CHAR_PAIRS {
        m.insert(*s, *t);
    }
    m
}

fn s2t_map() -> &'static HashMap<char, char> {
    S2T_CHAR.get_or_init(static_char_map)
}

fn t2s_map() -> &'static HashMap<char, char> {
    T2S_CHAR.get_or_init(|| {
        let s2t = s2t_map();
        let mut m = HashMap::with_capacity(s2t.len());
        for (s, t) in s2t {
            m.insert(*t, *s);
        }
        m
    })
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
        let s = "大家一起来听音乐吧";
        let t = convert_s2t(s);
        assert_eq!(convert_t2s(&t), s);
    }
}
