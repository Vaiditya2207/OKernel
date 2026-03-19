use axum::{
    extract::{Multipart, Path, Query, State},
    http::{StatusCode, HeaderMap},
    response::{IntoResponse, Response},
    Json,
    body::Body,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{PathBuf, Component};
use tokio::fs as tokio_fs;
use tokio::io::AsyncWriteExt;
use tracing::{info, error};

const STORAGE_DIR: &str = "storage/aether";

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct AetherVersion {
    pub version: String,
    pub description: String,
    pub changelog: String,
    pub release_date: String,
    pub filename: String,
    pub size: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bundle_filename: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bundle_size: Option<u64>,
}

#[derive(Deserialize)]
pub struct DownloadQuery {
    pub v: Option<String>,
}

pub async fn list_handlers() -> impl IntoResponse {
    let mut versions = Vec::new();
    let storage_path = PathBuf::from(STORAGE_DIR);

    if let Ok(entries) = fs::read_dir(&storage_path) {
        for entry in entries.flatten() {
            if let Ok(file_type) = entry.file_type() {
                if file_type.is_dir() {
                    let metadata_path = entry.path().join("metadata.json");
                    if metadata_path.exists() {
                        if let Ok(content) = fs::read_to_string(&metadata_path) {
                            if let Ok(version_data) = serde_json::from_str::<AetherVersion>(&content) {
                                versions.push(version_data);
                            }
                        }
                    }
                }
            }
        }
    }

    // Sort versions by release date (descending) - simple string sort for now, ideally parse dates
    versions.sort_by(|a, b| b.release_date.cmp(&a.release_date));

    Json(versions)
}

pub async fn latest_handler() -> Result<impl IntoResponse, (StatusCode, Json<serde_json::Value>)> {
    let mut versions = Vec::new();
    let storage_path = PathBuf::from(STORAGE_DIR);

    if let Ok(entries) = fs::read_dir(&storage_path) {
        for entry in entries.flatten() {
            if let Ok(file_type) = entry.file_type() {
                if file_type.is_dir() {
                    let metadata_path = entry.path().join("metadata.json");
                    if metadata_path.exists() {
                        if let Ok(content) = fs::read_to_string(&metadata_path) {
                            if let Ok(version_data) = serde_json::from_str::<AetherVersion>(&content) {
                                versions.push(version_data);
                            }
                        }
                    }
                }
            }
        }
    }

    if versions.is_empty() {
        return Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "No versions available"}))));
    }

    versions.sort_by(|a, b| b.release_date.cmp(&a.release_date));
    Ok(Json(versions.into_iter().next().unwrap()))
}

pub async fn download_handler(Query(params): Query<DownloadQuery>) -> Result<impl IntoResponse, (StatusCode, String)> {
    let version = params.v.unwrap_or_else(|| "latest".to_string());
    
    let target_version = if version == "latest" {
        // Find latest version
        let mut versions = Vec::new();
        let storage_path = PathBuf::from(STORAGE_DIR);
        if let Ok(entries) = fs::read_dir(&storage_path) {
            for entry in entries.flatten() {
                if entry.path().join("metadata.json").exists() {
                     versions.push(entry.file_name().to_string_lossy().to_string());
                }
            }
        }
        // Simple semantic version sort assumption or date based. 
        // For now, let's just create a list_handlers logic reuse or similar.
        // To keep it simple and without locking, re-read metadata.
         let mut version_objs = Vec::new();
         if let Ok(entries) = fs::read_dir(&storage_path) {
            for entry in entries.flatten() {
                 let metadata_path = entry.path().join("metadata.json");
                 if let Ok(content) = fs::read_to_string(&metadata_path) {
                     if let Ok(v) = serde_json::from_str::<AetherVersion>(&content) {
                         version_objs.push(v);
                     }
                 }
            }
         }
         version_objs.sort_by(|a, b| b.release_date.cmp(&a.release_date)); // Latest date first
         
         if let Some(latest) = version_objs.first() {
             latest.version.clone()
         } else {
             return Err((StatusCode::NOT_FOUND, "No versions available".to_string()));
         }
    } else {
        version
    };

    // Sanitize version path to prevent traversal
    if target_version.contains("..") || target_version.contains("/") || target_version.contains("\\") {
         return Err((StatusCode::BAD_REQUEST, "Invalid version format".to_string()));
    }

    let version_dir = PathBuf::from(STORAGE_DIR).join(&target_version);
    if !version_dir.exists() {
        return Err((StatusCode::NOT_FOUND, format!("Version {} not found", target_version)));
    }

    let metadata_path = version_dir.join("metadata.json");
    let metadata_content = fs::read_to_string(&metadata_path).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to read metadata".to_string()))?;
    let metadata: AetherVersion = serde_json::from_str(&metadata_content).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Invalid metadata".to_string()))?;

    let file_path = version_dir.join(&metadata.filename);
    
    // Serve file
    let file = tokio_fs::File::open(&file_path).await.map_err(|_| (StatusCode::NOT_FOUND, "File not found".to_string()))?;
    let stream = tokio_util::io::ReaderStream::new(file);
    let body = Body::from_stream(stream);

    let mut headers = HeaderMap::new();
    headers.insert(
        axum::http::header::CONTENT_TYPE, 
        "application/octet-stream".parse().unwrap() // Simplification: we know it's a binary/dmg
    );
    headers.insert(
        axum::http::header::CONTENT_DISPOSITION,
        format!("attachment; filename=\"{}\"", metadata.filename).parse().unwrap()
    );

    Ok((headers, body))
}

pub async fn upload_handler(
    headers: HeaderMap,
    mut multipart: Multipart,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    // 1. Auth Check
    let auth_header = headers.get("Authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "));

    let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
    
    if auth_header != Some(&expected_key) {
        return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
    }

    // 2. Parse Multipart
    let mut version: Option<String> = None;
    let mut description: Option<String> = None;
    let mut changelog: Option<String> = None;
    let mut file_bytes: Option<Vec<u8>> = None;
    let mut filename: Option<String> = None;

    while let Some(field) = multipart.next_field().await.map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))? {
        let name = field.name().unwrap_or("").to_string();
        
        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
            let data = field.bytes().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
            file_bytes = Some(data.to_vec());
        } else {
            let data = field.text().await.map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
            match name.as_str() {
                "version" => version = Some(data),
                "description" => description = Some(data),
                "changelog" => changelog = Some(data),
                _ => {}
            }
        }
    }

    let version = version.ok_or((StatusCode::BAD_REQUEST, "Missing version".to_string()))?;
    let file_bytes = file_bytes.ok_or((StatusCode::BAD_REQUEST, "Missing file".to_string()))?;
    let filename = filename.ok_or((StatusCode::BAD_REQUEST, "Missing filename".to_string()))?;
    let description = description.unwrap_or_default();
    let changelog = changelog.unwrap_or_default();

    // 3. Validation
    if version.contains("..") || version.contains("/") || version.contains("\\") {
         return Err((StatusCode::BAD_REQUEST, "Invalid version string".to_string()));
    }

    let version_dir = PathBuf::from(STORAGE_DIR).join(&version);
    if version_dir.exists() {
        return Err((StatusCode::CONFLICT, format!("Version {} already exists", version)));
    }

    // 4. Save to Disk
    tokio_fs::create_dir_all(&version_dir).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let metadata = AetherVersion {
        version: version.clone(),
        description,
        changelog,
        release_date: chrono::Utc::now().to_rfc3339(),
        filename: filename.clone(),
        size: file_bytes.len() as u64,
        bundle_filename: None,
        bundle_size: None,
    };

    let metadata_path = version_dir.join("metadata.json");
    let metadata_json = serde_json::to_string_pretty(&metadata).map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    tokio_fs::write(&metadata_path, metadata_json).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    info!("Published Aether version: {}", version);

    Ok((StatusCode::CREATED, format!("Version {} published successfully", version)))
}
