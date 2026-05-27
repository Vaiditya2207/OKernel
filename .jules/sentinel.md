## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-05-27 - Weak Default Secret Fallback
Vulnerability Pattern: Broken Auth via weak default secret fallback (`unwrap_or_else`).
Systemic Cause: The codebase uses `unwrap_or_else` on environment variables representing secrets (like `AETHER_UPLOAD_KEY`), falling back to a hardcoded string if the environment variable is missing. This prevents the application from failing securely when misconfigured.
Auditor Note: Always audit uses of `unwrap_or_else` or `unwrap_or` on environment variables, especially those used for authentication, encryption, or API keys. Ensure that missing secrets result in a secure failure state rather than a weak default.
