use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use formal_cloud::{
    api,
    store::{Error, Store},
};
use http_body_util::BodyExt;
use std::sync::{Arc, Barrier};
use tower::ServiceExt;

fn database() -> (tempfile::TempDir, Store) {
    let dir = tempfile::tempdir().unwrap();
    let store = Store::open(dir.path().join("quota.db")).unwrap();
    (dir, store)
}

#[test]
fn independent_connections_serialize_reservations() {
    let (_dir, store) = database();
    let barrier = Arc::new(Barrier::new(2));
    let accepted: usize = std::thread::scope(|scope| {
        let handles: Vec<_> = (0..2)
            .map(|_| {
                let s = store.clone();
                let b = barrier.clone();
                scope.spawn(move || {
                    b.wait();
                    usize::from(s.reserve("alice", 20, None).unwrap().accepted)
                })
            })
            .collect();
        handles.into_iter().map(|h| h.join().unwrap()).sum()
    });
    assert_eq!(accepted, 1);
    assert_eq!(store.snapshot("alice").unwrap().used, 90);
}

#[test]
fn concurrent_retries_allocate_once_and_survive_reopening() {
    let (dir, store) = database();
    let barrier = Arc::new(Barrier::new(8));
    let fresh: usize = std::thread::scope(|scope| {
        let handles: Vec<_> = (0..8)
            .map(|_| {
                let s = store.clone();
                let b = barrier.clone();
                scope.spawn(move || {
                    b.wait();
                    let r = s.reserve("alice", 10, Some("vm-1")).unwrap();
                    assert!(r.accepted);
                    usize::from(!r.replayed)
                })
            })
            .collect();
        handles.into_iter().map(|h| h.join().unwrap()).sum()
    });
    assert_eq!(fresh, 1);
    drop(store);
    let reopened = Store::open(dir.path().join("quota.db")).unwrap();
    assert!(
        reopened
            .reserve("alice", 10, Some("vm-1"))
            .unwrap()
            .replayed
    );
    assert_eq!(reopened.snapshot("alice").unwrap().used, 80);
    assert!(matches!(
        reopened.reserve("alice", 11, Some("vm-1")),
        Err(Error::KeyConflict)
    ));
}

#[test]
fn rejection_and_missing_tenant_do_not_allocate() {
    let (_dir, store) = database();
    assert!(
        !store
            .reserve("alice", u32::MAX, Some("large"))
            .unwrap()
            .accepted
    );
    assert!(
        store
            .reserve("alice", u32::MAX, Some("large"))
            .unwrap()
            .replayed
    );
    assert!(matches!(
        store.reserve("bob", 0, None),
        Err(Error::NotFound)
    ));
    assert_eq!(store.snapshot("alice").unwrap().used, 70);
}

#[test]
fn retry_without_key_is_a_second_operation() {
    let (_dir, store) = database();
    for _ in 0..2 {
        assert!(store.reserve("alice", 10, None).unwrap().accepted);
    }
    assert_eq!(store.snapshot("alice").unwrap().used, 90);
}

#[tokio::test]
async fn http_contract_and_lost_response_retry() {
    let (_dir, store) = database();
    let app = api::router(store.clone());
    for (cpus, key, status) in [
        ("10", "vm-1", StatusCode::OK),
        ("10", "vm-1", StatusCode::OK),
        ("11", "vm-1", StatusCode::CONFLICT),
        ("-1", "negative", StatusCode::UNPROCESSABLE_ENTITY),
        ("4294967296", "overflow", StatusCode::UNPROCESSABLE_ENTITY),
        ("40", "too-many", StatusCode::CONFLICT),
    ] {
        let req = Request::post("/reserve")
            .header("content-type", "application/json")
            .header("idempotency-key", key)
            .body(Body::from(format!(r#"{{"tenant":"alice","cpus":{cpus}}}"#)))
            .unwrap();
        let response = app.clone().oneshot(req).await.unwrap();
        assert_eq!(response.status(), status);
        // Dropping the first successful response models a client that never saw it.
    }
    let response = app
        .oneshot(Request::get("/quota/alice").body(Body::empty()).unwrap())
        .await
        .unwrap();
    let body = response.into_body().collect().await.unwrap().to_bytes();
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&body).unwrap()["used"],
        80
    );
}
