## 2024-05-24 - Unsanitized Multipart Filename in aether.rs
Vulnerability Pattern: Arbitrary File Write / Path Traversal via Unsanitized Multipart Filename.
Systemic Cause: `axum::extract::Multipart` does not sanitize filenames automatically; raw filenames provided by clients are passed directly into `PathBuf::join`, which can overwrite absolute paths or traverse directories.
Auditor Note: Always check `PathBuf::join` operations in Rust when dealing with user-controlled input (e.g., file uploads, archive extraction) to ensure path traversal sequences (`..`) or absolute paths are not permitted.
