## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Weak Default Fallback for Secrets in Aether
Vulnerability Pattern: Broken Auth via weak default fallback (`unwrap_or_else` providing a default string for missing environment variable secrets).
Systemic Cause: The application attempts to handle missing environment variables gracefully using `unwrap_or_else` but provides a predictable, weak default key (`"update_me_please"`), exposing critical endpoints if configuration management fails.
Auditor Note: Always audit `std::env::var` usage for secrets. Secrets must fail securely if missing, not fall back to weak defaults. Look for `unwrap_or_else` and `unwrap_or` patterns on sensitive environment variables.
