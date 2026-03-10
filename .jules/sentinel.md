## 2025-12-08 - Critical Path Traversal Vulnerability Pattern in Rust PathBuf
Vulnerability Pattern: Unsanitized file uploads using `PathBuf::join` with user-supplied filenames allow directory traversal (Arbitrary File Write).
Systemic Cause: The codebase assumes that `PathBuf::join` is safe or that higher-level frameworks sanitize filenames automatically, which `axum::extract::Multipart` does not do by default for `file_name()`.
Auditor Note: Always verify that file upload handlers sanitize the filename (e.g., using `Path::file_name` to strip directory components) before joining with a base directory. Look for `multipart.next_field()` followed by `field.file_name()` and direct usage in `fs::write` or `File::create`.
