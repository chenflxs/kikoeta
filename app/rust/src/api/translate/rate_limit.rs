use std::collections::{hash_map::RandomState, HashMap};
use std::hash::BuildHasher;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant, SystemTime};

use reqwest::header::{HeaderMap, RETRY_AFTER};

#[derive(Clone, Eq, Hash, PartialEq)]
pub(super) struct RateLimit {
    provider: &'static str,
    origin: String,
    account: u64,
}

type Cooldown = (Instant, Duration);
static COOLDOWNS: LazyLock<Mutex<HashMap<RateLimit, Cooldown>>> = LazyLock::new(Mutex::default);
static ACCOUNT_HASHER: LazyLock<RandomState> = LazyLock::new(RandomState::new);

impl RateLimit {
    pub(super) fn new(provider: &'static str, base: &str, key: &str) -> Self {
        let origin = reqwest::Url::parse(base)
            .map(|url| url.origin().ascii_serialization())
            .unwrap_or_default();
        Self {
            provider,
            origin,
            // Keep raw credentials out of the process-wide cooldown table.
            account: ACCOUNT_HASHER.hash_one(key.trim()),
        }
    }

    pub(super) fn check(&self) -> Result<(), String> {
        let cooldowns = COOLDOWNS.lock().unwrap();
        if let Some(wait) = cooldowns.get(self).and_then(remaining) {
            return Err(message(self.provider, wait));
        }
        Ok(())
    }

    pub(super) fn observe(&self, response: &reqwest::Response) -> Result<(), String> {
        if response.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            return Err(self.record(retry_after(response.headers())));
        }
        Ok(())
    }

    pub(super) fn record(&self, wait: Duration) -> String {
        let mut cooldowns = COOLDOWNS.lock().unwrap();
        cooldowns.retain(|_, cooldown| remaining(cooldown).is_some());
        if let Some(previous) = cooldowns.get(self).and_then(remaining) {
            if previous >= wait {
                return message(self.provider, previous);
            }
        }
        cooldowns.insert(self.clone(), (Instant::now(), wait));
        message(self.provider, wait)
    }
}

pub(super) fn remaining((started_at, wait): &Cooldown) -> Option<Duration> {
    wait.checked_sub(started_at.elapsed())
        .filter(|remaining| !remaining.is_zero())
}

pub(super) fn message(provider: &str, wait: Duration) -> String {
    let seconds = wait
        .as_secs()
        .saturating_add(u64::from(wait.subsec_nanos() > 0));
    format!("{provider} HTTP 429：请求受限，请在 {seconds} 秒后重试")
}

pub(super) fn retry_after(headers: &HeaderMap) -> Duration {
    let wait = headers
        .get(RETRY_AFTER)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .and_then(|value| {
            if !value.is_empty() && value.bytes().all(|byte| byte.is_ascii_digit()) {
                return Some(Duration::from_secs(value.parse().unwrap_or(u64::MAX)));
            }
            let date = httpdate::parse_http_date(value).ok()?;
            Some(date.duration_since(SystemTime::now()).unwrap_or_default())
        });
    wait.unwrap_or(Duration::from_secs(30))
        .max(Duration::from_secs(1))
}
