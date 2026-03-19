use axum::http::StatusCode;
use axum_test::TestServer;
use serde_json::json;
use syscore::create_app;
use syscore::docker::manager::MockContainerManager;
use std::sync::Arc;

async fn get_test_server() -> TestServer {
    let container_manager = Arc::new(MockContainerManager);
    let app = create_app(container_manager);
    TestServer::new(app).unwrap()
}

#[tokio::test]
async fn test_latest_handler() {
    let server = get_test_server().await;
    let response = server.get("/api/v1/aether/latest").await;
    
    // Stable channel is default. If no versions exist, 404 is expected.
    assert!(response.status_code() == StatusCode::OK || response.status_code() == StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_telemetry_handler() {
    let server = get_test_server().await;
    
    let telemetry = json!({
        "version": "0.4.0",
        "event": "update_success",
        "channel": "stable",
        "os": "macos"
    });

    let response = server
        .post("/api/v1/aether/telemetry")
        .json(&telemetry)
        .await;

    response.assert_status(StatusCode::OK);
}

#[tokio::test]
async fn test_list_handler() {
    let server = get_test_server().await;
    let response = server.get("/api/v1/aether").await;
    
    response.assert_status(StatusCode::OK);
    let body: serde_json::Value = response.json();
    assert!(body.is_array());
}

