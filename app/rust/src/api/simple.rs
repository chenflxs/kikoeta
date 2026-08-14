#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

use std::sync::Mutex;

use rusqlite::Connection;

static DB: Mutex<Option<Connection>> = Mutex::new(None);

/// 打开（或创建）设置数据库，并建好 settings 表。
#[flutter_rust_bridge::frb(sync)]
pub fn open_settings(path: String) -> Result<(), String> {
    let conn = Connection::open(&path).map_err(|e| e.to_string())?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );",
    )
    .map_err(|e| e.to_string())?;
    *DB.lock().map_err(|e| e.to_string())? = Some(conn);
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_setting(key: String) -> Option<String> {
    let guard = DB.lock().ok()?;
    let conn = guard.as_ref()?;
    conn.query_row("SELECT value FROM settings WHERE key = ?1", [&key], |row| row.get(0))
        .ok()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_setting(key: String, value: String) -> Result<(), String> {
    let guard = DB.lock().map_err(|e| e.to_string())?;
    let conn = guard.as_ref().ok_or_else(|| "settings db not opened".to_string())?;
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        [&key, &value],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// 清空全部设置与 token（「完全重置」用）
#[flutter_rust_bridge::frb(sync)]
pub fn clear_all_settings() -> Result<(), String> {
    let guard = DB.lock().map_err(|e| e.to_string())?;
    let conn = guard.as_ref().ok_or_else(|| "settings db not opened".to_string())?;
    conn.execute("DELETE FROM settings", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[flutter_rust_bridge::frb(sync)]
pub fn rust_platform() -> String {
    format!("{}-{}", std::env::consts::OS, std::env::consts::ARCH)
}

/// 按服务器保存登录 token（本地 SQLite）
pub fn save_token_for_base(base: &str, token: &str) -> Result<(), String> {
    let key = format!("token:{}", base);
    let guard = DB.lock().map_err(|e| e.to_string())?;
    let conn = guard.as_ref().ok_or_else(|| "settings db not opened".to_string())?;
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        [&key, token],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// 读取某服务器的 token
pub fn token_for_base(base: &str) -> Option<String> {
    let key = format!("token:{}", base);
    let guard = DB.lock().ok()?;
    let conn = guard.as_ref()?;
    conn.query_row("SELECT value FROM settings WHERE key = ?1", [&key], |row| row.get(0))
        .ok()
}

/// 供 Dart 获取某服务器的 token（用于播放器流请求头）
#[flutter_rust_bridge::frb(sync)]
pub fn get_token(base: String) -> Option<String> {
    token_for_base(&base)
}

/// 读取 HTTP 代理配置（仅支持 HTTP 代理；未启用/非法时返回 None）
pub fn http_proxy_config() -> Option<String> {
    let guard = DB.lock().ok()?;
    let conn = guard.as_ref()?;
    let enabled: bool = conn
        .query_row(
            "SELECT value FROM settings WHERE key='http_proxy_enabled'",
            [],
            |r| r.get::<_, String>(0),
        )
        .ok()
        .map(|v| v == "1")
        .unwrap_or(false);
    if !enabled {
        return None;
    }
    let url: String = conn
        .query_row(
            "SELECT value FROM settings WHERE key='http_proxy'",
            [],
            |r| r.get(0),
        )
        .ok()?;
    let t = url.trim();
    if t.is_empty() {
        return None;
    }
    let lower = t.to_ascii_lowercase();
    if lower.starts_with("socks") || lower.starts_with("https://") {
        return None; // 仅支持 HTTP 协议代理
    }
    Some(if lower.starts_with("http://") {
        t.to_string()
    } else {
        format!("http://{t}")
    })
}
