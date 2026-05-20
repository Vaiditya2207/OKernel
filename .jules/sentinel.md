## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-20 - Hardcoded Weak Default in Aether Upload Auth
Vulnerability Pattern: Broken Auth / Hardcoded Secret via `unwrap_or_else` fallback.
Systemic Cause: The system falls back to a weak, hardcoded default credential ("update_me_please") when the required environment variable (`AETHER_UPLOAD_KEY`) is missing. This bypasses the intended security requirement for a secret key.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials. Ensure they fail securely (e.g., panicking or returning an error) rather than supplying weak default fallbacks.
