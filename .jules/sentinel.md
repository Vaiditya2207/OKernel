## 2026-02-28 - Arbitrary File Write in Aether Upload
Vulnerability Pattern: Arbitrary File Write via Path Traversal in multipart upload filenames.
Systemic Cause: The `axum::extract::Multipart` field `file_name()` method is used directly without sanitization, allowing an attacker to supply a filename like `../../../../../etc/passwd` or `/etc/passwd`. `PathBuf::join` replaces the base path if the argument is an absolute path.
Auditor Note: Always check if `PathBuf::join` is used with unverified user input. In Rust, joining an absolute path to a base path discards the base path. Filenames from multipart form data must always be sanitized or stripped of directory components.
