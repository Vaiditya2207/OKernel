use std::net::SocketAddr;
use syscore::docker::manager::{ContainerManager, ContainerManagerTrait};
use syscore::{create_app, init_tracing};

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();
    // Initialize tracing
    init_tracing();

    tracing::info!("SysCore Engine v2.0 initializing...");
    tracing::info!("CWD: {:?}", std::env::current_dir().ok());

    // Ensure Aether storage exists
    if let Err(e) = std::fs::create_dir_all("storage/aether") {
        tracing::error!("Failed to create storage/aether: {}", e);
    }

    // Initialize Docker connection
    let container_manager = match ContainerManager::new() {
        Ok(cm) => {
            tracing::info!("Docker connection established");
            cm
        },
        Err(e) => {
            tracing::error!("Failed to connect to Docker: {}", e);
            std::process::exit(1);
        }
    };

    // Pre-flight check: Ensure Docker is actually running and usable
    if let Err(e) = container_manager.health_check().await {
        tracing::error!("CRITICAL: Docker health check failed. The execution engine cannot start.");
        tracing::error!("Reason: {}", e);
        tracing::error!("Please ensure Docker Desktop/Engine is running.");
        std::process::exit(1); 
    }

    // Build application with routes
    let app = create_app(std::sync::Arc::new(container_manager));

    // Address to listen on
    let addr = SocketAddr::from(([127, 0, 0, 1], 3001));
    tracing::info!("Listening on {}", addr);

    // Start server
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
