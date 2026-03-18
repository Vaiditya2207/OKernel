use axum::{Json, extract::State};
use serde::{Deserialize, Serialize};
use crate::docker::manager::{ContainerManagerTrait, Language};
use crate::simulation::{SimulationState, next_tick};
use crate::vm::{VMState, VMMallocRequest, VMWriteRequest, FSOperationRequest, FSOperationResponse};
use std::sync::Arc;
use super::aether; // Import local module from parent server module if needed, or crate::server::aether

#[derive(Deserialize)]
pub struct ExecuteRequest {
    pub language: String,
    pub code: String,
}

#[derive(Serialize)]
pub struct ExecuteResponse {
    pub status: String,
    pub output: String,
}

pub async fn execute_handler(
    State(manager): State<Arc<dyn ContainerManagerTrait>>,
    Json(payload): Json<ExecuteRequest>,
) -> Json<ExecuteResponse> {
    let lang = match payload.language.as_str() {
        "python" => Language::Python,
        "cpp" | "c++" => Language::Cpp,
        _ => return Json(ExecuteResponse {
            status: "error".to_string(),
            output: "Unsupported language".to_string(),
        }),
    };

    match manager.execute(lang, payload.code).await {
        Ok(result) => Json(ExecuteResponse {
            status: "success".to_string(),
            output: result,
        }),
        Err(e) => Json(ExecuteResponse {
            status: "error".to_string(),
            output: e,
        }),
    }
}

pub async fn simulate_tick_handler(
    Json(payload): Json<SimulationState>,
) -> Json<SimulationState> {
    let next_state = next_tick(payload);
    Json(next_state)
}

pub async fn vm_malloc_handler(
    Json(payload): Json<VMMallocRequest>,
) -> Json<Result<VMState, String>> {
    let mut state = payload.state;
    match state.memory.malloc(payload.size) {
        Ok(_) => Json(Ok(state)),
        Err(e) => Json(Err(e)),
    }
}

pub async fn vm_write_handler(
    Json(payload): Json<VMWriteRequest>,
) -> Json<VMState> {
    let mut state = payload.state;
    if payload.is_string {
        state.memory.write_string(payload.address, &payload.data);
    } else {
        // Assume data is a number if not string
        if let Ok(val) = payload.data.parse::<i32>() {
            state.memory.write32(payload.address, val);
        }
    }
    Json(state)
}

pub async fn vm_reset_handler(
    Json(mut state): Json<VMState>,
) -> Json<VMState> {
    state.memory.reset();
    Json(state)
}

pub async fn vm_fs_handler(
    Json(payload): Json<FSOperationRequest>,
) -> Json<FSOperationResponse> {
    // For now, we use a static FS since we don't have a persistent session-based FS yet
    let mut fs = crate::vm::fs::MockFileSystem::new();
    
    match payload.op.as_str() {
        "ls" => {
            Json(FSOperationResponse {
                success: true,
                files: Some(fs.list_files()),
                content: None,
                error: None,
            })
        },
        "create" => {
            if let Some(name) = payload.name {
                fs.create_file(name);
                Json(FSOperationResponse {
                    success: true,
                    files: None,
                    content: None,
                    error: None,
                })
            } else {
                Json(FSOperationResponse {
                    success: false,
                    files: None,
                    content: None,
                    error: Some("Name missing".to_string()),
                })
            }
        },
        _ => Json(FSOperationResponse {
            success: false,
            files: None,
            content: None,
            error: Some("Unknown op".to_string()),
        })
    }
}
