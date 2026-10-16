use formal_cloud::{api, store::Store};

#[tokio::main]
async fn main() {
    let path = std::env::var("QUOTA_DB").unwrap_or_else(|_| "var/quota.db".into());
    if let Some(parent) = std::path::Path::new(&path).parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent).expect("create database directory");
        }
    }
    let store = Store::open(path).expect("initialize database");
    let addr = std::env::var("QUOTA_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".into());
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("bind server");
    println!("Quota API at http://{addr}; alice starts at 70/100 in a new database");
    axum::serve(listener, api::router(store))
        .await
        .expect("serve");
}
