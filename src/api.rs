use crate::store::{Error, Store};
use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;

pub fn router(store: Store) -> Router {
    Router::new()
        .route("/reserve", post(reserve))
        .route("/quota/{tenant}", get(quota))
        .with_state(store)
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    tenant: String,
    cpus: u32,
}

async fn reserve(
    State(store): State<Store>,
    headers: HeaderMap,
    Json(request): Json<Request>,
) -> Response {
    let key = match headers.get("idempotency-key") {
        Some(value) => match value.to_str() {
            Ok(s) if !s.trim().is_empty() && s.len() <= 128 => Some(s.to_owned()),
            _ => {
                return (
                    StatusCode::BAD_REQUEST,
                    "idempotency-key must contain 1–128 ASCII bytes",
                )
                    .into_response()
            }
        },
        None => None,
    };
    if request.tenant.trim().is_empty() {
        return (StatusCode::BAD_REQUEST, "tenant is required").into_response();
    }
    match tokio::task::spawn_blocking(move || {
        store.reserve(&request.tenant, request.cpus, key.as_deref())
    })
    .await
    {
        Ok(Ok(result)) => (
            if result.accepted {
                StatusCode::OK
            } else {
                StatusCode::CONFLICT
            },
            Json(result),
        )
            .into_response(),
        Ok(Err(e)) => error(e),
        Err(e) => {
            eprintln!("worker error: {e}");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

async fn quota(State(store): State<Store>, Path(tenant): Path<String>) -> Response {
    match tokio::task::spawn_blocking(move || store.snapshot(&tenant)).await {
        Ok(Ok(q)) => Json(q).into_response(),
        Ok(Err(e)) => error(e),
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

fn error(e: Error) -> Response {
    match e {
        Error::NotFound => (StatusCode::NOT_FOUND, "unknown tenant").into_response(),
        Error::KeyConflict => (
            StatusCode::CONFLICT,
            "idempotency key reused with different cpus",
        )
            .into_response(),
        Error::Db(e) => {
            eprintln!("database error: {e}");
            (
                StatusCode::SERVICE_UNAVAILABLE,
                "database unavailable; retry with the same idempotency key",
            )
                .into_response()
        }
    }
}
