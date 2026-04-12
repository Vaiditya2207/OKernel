## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Fallback Secret in Aether Upload
Vulnerability Pattern: Hardcoded default string used as API key fallback via `unwrap_or_else`.
Systemic Cause: The developer used `unwrap_or_else` on an `env::var` call to provide a default "dev-friendly" value (`update_me_please`) instead of failing securely when the environment variable is missing.
Auditor Note: Always search for `unwrap_or_else`, `unwrap_or`, and `.env::var` combinations to identify weak default secrets that could be exposed in production environments. Fail securely rather than degrading gracefully into insecure states.
