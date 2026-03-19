pub mod docker;
pub mod server;
pub mod profiler;
pub mod simulation;
pub mod vm;

use axum::{
    routing::{get, post},
    Router,
};
use tower_http::limit::RequestBodyLimitLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::sync::Arc;
use crate::docker::manager::ContainerManagerTrait;
use crate::server::routes::{execute_handler, simulate_tick_handler, vm_malloc_handler, vm_write_handler, vm_reset_handler, vm_fs_handler};
use crate::server::aether::{upload_handler, list_handlers, download_handler, latest_handler, bundle_download_handler};
use crate::server::websocket::websocket_handler;

pub fn create_app(container_manager: Arc<dyn ContainerManagerTrait>) -> Router {
    Router::new()
        .route("/health", get(health_check))
        .route("/api/execute", post(execute_handler))
        .route("/api/simulate/cpu/tick", post(simulate_tick_handler))
        .route("/api/vm/malloc", post(vm_malloc_handler))
        .route("/api/vm/write", post(vm_write_handler))
        .route("/api/vm/reset", post(vm_reset_handler))
        .route("/api/vm/fs/ls", post(vm_fs_handler))
        .route("/api/vm/fs/create", post(vm_fs_handler))
        .route("/api/v1/aether", get(list_handlers).post(upload_handler))
        .route("/api/v1/aether/latest", get(latest_handler))
        .route("/api/v1/aether/download", get(download_handler))
        .route("/api/v1/aether/download/bundle", get(bundle_download_handler))
        .route("/ws/stream", get(websocket_handler))
        .layer(RequestBodyLimitLayer::new(50 * 1024 * 1024)) // 50MB limit for Aether uploads
        .layer(
            tower_http::cors::CorsLayer::new()
                .allow_origin([
                    "https://www.hackmist.tech".parse().unwrap(),
                    "https://hackmist.tech".parse().unwrap(),
                    "http://localhost:5173".parse().unwrap(),
                ])
                .allow_methods([
                    axum::http::Method::GET,
                    axum::http::Method::POST,
                    axum::http::Method::OPTIONS,
                ])
                .allow_headers([
                    axum::http::header::CONTENT_TYPE,
                    axum::http::header::AUTHORIZATION,
                ]),
        )
        .with_state(container_manager)
}

pub fn init_tracing() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "syscore=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();
}

pub async fn health_check() -> String {
    let version = option_env!("SYSCORE_VERSION").unwrap_or("unknown");
    format!("SysCore Backend: ONLINE (Build: {})", version)
}
