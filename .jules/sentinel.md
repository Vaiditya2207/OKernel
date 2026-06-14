## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Weak Default Credential Fallback
Vulnerability Pattern: Hardcoded Secrets / Weak Default Fallback using `unwrap_or_else` for environment variables.
Systemic Cause: In `syscore/src/server/aether.rs`, the server falls back to a weak default credential ('update_me_please') if the `AETHER_UPLOAD_KEY` environment variable is not set, bypassing standard security practices of failing securely.
Auditor Note: Always check usages of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials. Ensure they fail securely rather than supplying weak default fallbacks.
