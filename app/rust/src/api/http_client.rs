//! Shared asynchronous HTTP clients. Authentication remains per request.

use std::sync::Mutex;
use std::time::Duration;

use crate::api::simple;

const API_USER_AGENT: &str = "Kikoeta/0.1 (flutter demo)";
const TRANSLATION_USER_AGENT: &str = "Kikoeta/0.1 (translate)";
const API_TIMEOUT: Duration = Duration::from_secs(20);
const TRANSLATION_TIMEOUT: Duration = Duration::from_secs(30);

static API_CLIENT: ClientPool = ClientPool::new(API_USER_AGENT, API_TIMEOUT);
static TRANSLATION_CLIENT: ClientPool =
    ClientPool::new(TRANSLATION_USER_AGENT, TRANSLATION_TIMEOUT);

pub(super) fn api_client() -> Result<reqwest::Client, String> {
    API_CLIENT.client_for_proxy(simple::http_proxy_config())
}

pub(super) fn translation_client() -> Result<reqwest::Client, String> {
    TRANSLATION_CLIENT.client_for_proxy(simple::http_proxy_config())
}

pub(super) struct ClientPool {
    cached: Mutex<Option<(Option<String>, reqwest::Client)>>,
    user_agent: &'static str,
    timeout: Duration,
    #[cfg(test)]
    no_environment_proxy: bool,
}

impl ClientPool {
    const fn new(user_agent: &'static str, timeout: Duration) -> Self {
        Self {
            cached: Mutex::new(None),
            user_agent,
            timeout,
            #[cfg(test)]
            no_environment_proxy: false,
        }
    }

    pub(super) fn client_for_proxy(
        &self,
        configured_proxy: Option<String>,
    ) -> Result<reqwest::Client, String> {
        // Keep the existing invalid-address fallback, and use the proxy that
        // will actually be applied as the connection-pool cache key.
        let proxy = configured_proxy
            .and_then(|url| reqwest::Proxy::all(&url).ok().map(|proxy| (url, proxy)));
        let key = proxy.as_ref().map(|(url, _)| url.clone());
        let mut cached = self.cached.lock().map_err(|e| e.to_string())?;
        if let Some((cached_proxy, client)) = cached.as_ref() {
            if *cached_proxy == key {
                return Ok(client.clone());
            }
        }
        let mut builder = reqwest::Client::builder()
            .user_agent(self.user_agent)
            .timeout(self.timeout);
        #[cfg(test)]
        if self.no_environment_proxy {
            builder = builder.no_proxy();
        }
        if let Some((_, proxy)) = proxy {
            builder = builder.proxy(proxy);
        }
        let client = builder
            .build()
            .map_err(|e| format!("创建 HTTP 客户端失败: {e}"))?;
        // Running requests keep clones of the previous client and its pool.
        *cached = Some((key, client.clone()));
        Ok(client)
    }

    #[cfg(test)]
    pub(super) fn for_testing(user_agent: &'static str, timeout: Duration) -> Self {
        Self {
            no_environment_proxy: true,
            ..Self::new(user_agent, timeout)
        }
    }
}

#[cfg(test)]
pub(super) mod test_support {
    use std::collections::HashSet;
    use std::net::SocketAddr;
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    };
    use std::thread::{self, JoinHandle};
    use std::time::Duration;

    #[derive(Clone, Debug)]
    pub(crate) struct RequestRecord {
        pub target: String,
        pub authorization: Option<String>,
        pub user_agent: Option<String>,
        pub peer: SocketAddr,
    }

    pub(crate) struct TestServer {
        pub base: String,
        records: Arc<Mutex<Vec<RequestRecord>>>,
        stopped: Arc<AtomicBool>,
        worker: Option<JoinHandle<()>>,
    }

    impl TestServer {
        pub(crate) fn new(handler: impl Fn(&str) -> String + Send + 'static) -> Self {
            Self::with_response(move |target| tiny_http::Response::from_string(handler(target)))
        }

        pub(crate) fn with_response(
            handler: impl Fn(&str) -> tiny_http::Response<std::io::Cursor<Vec<u8>>> + Send + 'static,
        ) -> Self {
            let server = tiny_http::Server::http("127.0.0.1:0").unwrap();
            let base = format!("http://{}", server.server_addr());
            let records = Arc::new(Mutex::new(Vec::new()));
            let received = records.clone();
            let stopped = Arc::new(AtomicBool::new(false));
            let should_stop = stopped.clone();
            let worker = thread::spawn(move || {
                while !should_stop.load(Ordering::SeqCst) {
                    let Some(mut request) = server
                        .recv_timeout(Duration::from_millis(50))
                        .unwrap()
                    else {
                        continue;
                    };
                    let header = |name: &str| {
                        request
                            .headers()
                            .iter()
                            .find(|header| {
                                header.field.as_str().as_str().eq_ignore_ascii_case(name)
                            })
                            .map(|header| header.value.as_str().to_string())
                    };
                    let record = RequestRecord {
                        target: request.url().to_string(),
                        authorization: header("authorization"),
                        user_agent: header("user-agent"),
                        peer: *request.remote_addr().unwrap(),
                    };
                    let target = record.target.clone();
                    received.lock().unwrap().push(record);
                    let mut body = Vec::new();
                    std::io::Read::read_to_end(request.as_reader(), &mut body).unwrap();
                    // A timed-out or cancelled user request can close its socket.
                    let _ = request.respond(handler(&target));
                }
            });
            Self {
                base,
                records,
                stopped,
                worker: Some(worker),
            }
        }

        pub(crate) fn records(&self) -> Vec<RequestRecord> {
            self.records.lock().unwrap().clone()
        }

        pub(crate) fn connections(&self) -> usize {
            self.records()
                .iter()
                .map(|record| record.peer)
                .collect::<HashSet<_>>()
                .len()
        }
    }

    impl Drop for TestServer {
        fn drop(&mut self) {
            self.stopped.store(true, Ordering::SeqCst);
            self.worker.take().unwrap().join().unwrap();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use test_support::TestServer;

    async fn get(client: &reqwest::Client, url: &str) -> String {
        client.get(url).send().await.unwrap().text().await.unwrap()
    }

    #[test]
    fn repeated_requests_reuse_connections_with_separate_policies() {
        let server = TestServer::new(|_| "ok".to_string());
        let api = ClientPool::for_testing(API_USER_AGENT, API_TIMEOUT);
        let translation =
            ClientPool::for_testing(TRANSLATION_USER_AGENT, TRANSLATION_TIMEOUT);
        assert_eq!(api.timeout, Duration::from_secs(20));
        assert_eq!(translation.timeout, Duration::from_secs(30));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            for _ in 0..3 {
                assert_eq!(
                    get(&api.client_for_proxy(None).unwrap(), &server.base).await,
                    "ok"
                );
            }
            for _ in 0..3 {
                assert_eq!(
                    get(&translation.client_for_proxy(None).unwrap(), &server.base).await,
                    "ok"
                );
            }
        });
        let requests = server.records();
        assert_eq!(requests.len(), 6);
        assert_eq!(server.connections(), 2);
        assert!(requests[..3]
            .iter()
            .all(|r| r.user_agent.as_deref() == Some(API_USER_AGENT)));
        assert!(requests[3..]
            .iter()
            .all(|r| r.user_agent.as_deref() == Some(TRANSLATION_USER_AGENT)));
    }

    #[test]
    fn proxy_changes_route_new_requests_without_aborting_in_flight_requests() {
        let (entered_tx, entered_rx) = std::sync::mpsc::channel();
        let (release_tx, release_rx) = std::sync::mpsc::channel();
        let first_proxy = TestServer::new(move |target| {
            if target.ends_with("/slow") {
                entered_tx.send(()).unwrap();
                release_rx.recv_timeout(Duration::from_secs(5)).unwrap();
            }
            "first".to_string()
        });
        let second_proxy = TestServer::new(|_| "second".to_string());
        let direct = TestServer::new(|_| "direct".to_string());
        let pool = ClientPool::for_testing(API_USER_AGENT, API_TIMEOUT);
        let old_client = pool
            .client_for_proxy(Some(first_proxy.base.clone()))
            .unwrap();
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let request_client = old_client.clone();
            let pending = tokio::spawn(async move {
                get(&request_client, "http://example.invalid/slow").await
            });
            entered_rx.recv_timeout(Duration::from_secs(5)).unwrap();
            for _ in 0..2 {
                let current = pool
                    .client_for_proxy(Some(second_proxy.base.clone()))
                    .unwrap();
                assert_eq!(get(&current, "http://example.invalid/new").await, "second");
            }
            assert!(!pending.is_finished());
            release_tx.send(()).unwrap();
            assert_eq!(pending.await.unwrap(), "first");
            assert_eq!(
                get(&old_client, "http://example.invalid/retained").await,
                "first"
            );
            assert_eq!(
                get(&pool.client_for_proxy(None).unwrap(), &direct.base).await,
                "direct"
            );
        });
        assert_eq!(first_proxy.connections(), 1);
        assert_eq!(second_proxy.connections(), 1);
        assert_eq!(direct.connections(), 1);
        assert!(first_proxy
            .records()
            .iter()
            .all(|r| r.target.starts_with("http://example.invalid/")));
        assert!(second_proxy
            .records()
            .iter()
            .all(|r| r.target.starts_with("http://example.invalid/")));
    }

    #[test]
    fn invalid_proxy_reuses_the_direct_pool() {
        let server = TestServer::new(|_| "ok".to_string());
        let pool = ClientPool::for_testing(API_USER_AGENT, API_TIMEOUT);
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            for proxy in [None, Some("http://[invalid".to_string()), None] {
                assert_eq!(
                    get(&pool.client_for_proxy(proxy).unwrap(), &server.base).await,
                    "ok"
                );
            }
        });
        assert_eq!(server.connections(), 1);
    }
    #[test]
    fn reconnecting_after_a_refused_connection_keeps_the_client_usable() {
        let reserved = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = reserved.local_addr().unwrap();
        drop(reserved);
        let url = format!("http://{address}/retry");
        let pool = ClientPool::for_testing(API_USER_AGENT, Duration::from_secs(2));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let client = pool.client_for_proxy(None).unwrap();
            let error = client.get(&url).send().await.unwrap_err();
            assert!(error.is_connect() || error.is_timeout(), "{error:?}");
            let server = tiny_http::Server::http(address).unwrap();
            let worker = std::thread::spawn(move || {
                let request = server.recv_timeout(Duration::from_secs(3)).unwrap().unwrap();
                request.respond(tiny_http::Response::from_string("reconnected")).unwrap();
            });
            assert_eq!(get(&pool.client_for_proxy(None).unwrap(), &url).await, "reconnected");
            worker.join().unwrap();
        });
    }

    #[test]
    fn a_timed_out_request_does_not_poison_later_requests() {
        let (entered_tx, entered_rx) = std::sync::mpsc::channel();
        let (release_tx, release_rx) = std::sync::mpsc::channel();
        let server = TestServer::new(move |target| {
            if target == "/slow" {
                entered_tx.send(()).unwrap();
                release_rx.recv_timeout(Duration::from_secs(3)).unwrap();
            }
            "recovered".to_string()
        });
        let pool = ClientPool::for_testing(API_USER_AGENT, Duration::from_millis(200));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let client = pool.client_for_proxy(None).unwrap();
            let slow_client = client.clone();
            let slow_url = format!("{}/slow", server.base);
            let pending = tokio::spawn(async move { slow_client.get(slow_url).send().await });
            entered_rx.recv_timeout(Duration::from_secs(3)).unwrap();
            assert!(pending.await.unwrap().unwrap_err().is_timeout());
            release_tx.send(()).unwrap();
            assert_eq!(
                get(&pool.client_for_proxy(None).unwrap(), &format!("{}/retry", server.base)).await,
                "recovered"
            );
        });
        assert_eq!(server.records().len(), 2);
    }

    #[test]
    fn cancelling_one_origin_does_not_block_another_origin() {
        let (entered_tx, entered_rx) = std::sync::mpsc::channel();
        let (release_tx, release_rx) = std::sync::mpsc::channel();
        let slow = TestServer::new(move |_| {
            entered_tx.send(()).unwrap();
            release_rx.recv_timeout(Duration::from_secs(3)).unwrap();
            "late".to_string()
        });
        let fast = TestServer::new(|_| "visible".to_string());
        let pool = ClientPool::for_testing(API_USER_AGENT, Duration::from_secs(2));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let old_client = pool.client_for_proxy(None).unwrap();
            let slow_url = slow.base.clone();
            let pending = tokio::spawn(async move { get(&old_client, &slow_url).await });
            entered_rx.recv_timeout(Duration::from_secs(3)).unwrap();
            assert_eq!(get(&pool.client_for_proxy(None).unwrap(), &fast.base).await, "visible");
            assert!(!pending.is_finished());
            pending.abort();
            assert!(pending.await.unwrap_err().is_cancelled());
            release_tx.send(()).unwrap();
            assert_eq!(get(&pool.client_for_proxy(None).unwrap(), &fast.base).await, "visible");
        });
        assert_eq!(fast.connections(), 1);
    }

    #[test]
    fn fixing_an_unavailable_proxy_and_switching_back_routes_every_new_request() {
        let reserved = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let unavailable = format!("http://{}", reserved.local_addr().unwrap());
        drop(reserved);
        let first = TestServer::new(|_| "first".to_string());
        let second = TestServer::new(|_| "second".to_string());
        let direct = TestServer::new(|_| "direct".to_string());
        let pool = ClientPool::for_testing(API_USER_AGENT, Duration::from_secs(2));
        let runtime = tokio::runtime::Runtime::new().unwrap();
        runtime.block_on(async {
            let error = pool.client_for_proxy(Some(unavailable)).unwrap()
                .get("http://example.invalid/work").send().await.unwrap_err();
            assert!(error.is_connect() || error.is_timeout(), "{error:?}");
            for (proxy, expected) in [(&first, "first"), (&second, "second"), (&first, "first")] {
                assert_eq!(get(&pool.client_for_proxy(Some(proxy.base.clone())).unwrap(),
                    "http://example.invalid/work").await, expected);
            }
            assert_eq!(get(&pool.client_for_proxy(None).unwrap(), &direct.base).await, "direct");
        });
        assert_eq!(first.records().len(), 2);
        assert_eq!(second.records().len(), 1);
        assert_eq!(direct.records().len(), 1);
    }
}
