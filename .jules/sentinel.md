## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Default AETHER_UPLOAD_KEY in Aether File Upload
Vulnerability Pattern: Weak default hardcoded secrets for authentication mechanisms.
Systemic Cause: The `upload_handler` falls back to `unwrap_or_else(|_| "update_me_please".to_string())` when looking for the `AETHER_UPLOAD_KEY` environment variable. This allows unauthenticated, trivial access to critical endpoints in unconfigured environments.
Auditor Note: Look for uses of `unwrap_or_else` or `unwrap_or` that supply default fallback secrets or credentials instead of failing securely when critical environment variables are absent.
