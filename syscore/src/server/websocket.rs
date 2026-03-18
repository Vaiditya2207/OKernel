use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures::{sink::SinkExt, stream::StreamExt};
use crate::docker::manager::ContainerManagerTrait;
use std::sync::Arc;

pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    State(manager): State<Arc<dyn ContainerManagerTrait>>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, manager))
}

async fn handle_socket(socket: WebSocket, manager: Arc<dyn ContainerManagerTrait>) {
    let (mut sender, mut receiver) = socket.split();

    // In a real implementation we would:
    // 1. Receive a "subscribe" message with jobId
    // 2. Look up the job/container
    // 3. Spawn a tokio task to stream logs/profiling data to 'sender'
    
    while let Some(msg) = receiver.next().await {
        if let Ok(msg) = msg {
            if let Message::Text(text) = msg {
                // Parse message (expecting simple "subscribe:job_id" for now)
                if text.starts_with("subscribe:") {
                    let job_id = text.trim_start_matches("subscribe:").trim();
                    tracing::info!("WS subscribing to job: {}", job_id);
                    
                    if let Some(mut rx) = manager.subscribe(job_id).await {
                        // Spawn a task to forward broadcast messages to this websocket
                        // Note: Requires cloning sender, which is actually tricky with axum's split sink
                        // Easier approach: Just loop here and select! between receiver and broadcast
                        
                        loop {
                            tokio::select! {
                                // Forward logs to WS
                                log_result = rx.recv() => {
                                    let log: String = match log_result {
                                        Ok(content) => content,
                                        Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                                            tracing::warn!("Broadcast lagged, continuing...");
                                            continue;
                                        }
                                        Err(_) => {
                                            tracing::warn!("Broadcast closed");
                                            break;
                                        }
                                    };
                                    
                                    if sender.send(Message::Text(log)).await.is_err() {
                                        break;
                                    }
                                }
                                // Keep reading from WS (ping/pong/close)
                                ws_msg = receiver.next() => {
                                    match ws_msg {
                                        Some(Ok(Message::Close(_))) | None => return,
                                        _ => {} // Ignore other messages while streaming
                                    }
                                }
                            }
                        }
                    } else {
                        let _ = sender.send(Message::Text("ERROR: Job not found".to_string())).await;
                    }
                }
            }
        } else {
            break;
        }
    }
}
