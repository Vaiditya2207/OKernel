## 2024-05-24 - [Arbitrary File Write in Aether Uploads]
Vulnerability Pattern: Path Traversal / Arbitrary File Write
Systemic Cause: `axum::extract::Multipart` does not sanitize filenames automatically; raw filenames are used directly in `tokio_fs::write`.
Auditor Note: Always check for manual sanitization when handling multipart uploads in Rust/Axum.

## 2024-05-24 - [Weak Authentication in Aether Uploads]
Vulnerability Pattern: Hardcoded/Weak Default Secret
Systemic Cause: The `AETHER_UPLOAD_KEY` environment variable falls back to `"update_me_please"`.
Auditor Note: Look for `.unwrap_or_else` on environment variable lookups that define security boundaries.
