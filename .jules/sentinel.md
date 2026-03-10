
## 2024-05-24 - Arbitrary File Write via Path Traversal in Aether Upload
Vulnerability Pattern: Unsanitized input from multipart/form-data `filename` field used directly in `PathBuf::join` allowing absolute path overwrites or directory traversal.
Systemic Cause: Lack of awareness regarding `axum::extract::Multipart` behavior not automatically sanitizing filenames and Rust's `PathBuf::join` replacing the base path entirely when given an absolute path.
Auditor Note: Always check file upload endpoints and multipart form data parsing for proper path sanitization, specifically looking for `PathBuf::join` usage with user-controlled input in Rust backends.
