## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Weak Default Credential Fallback
Vulnerability Pattern: Hardcoded default fallback for secret environment variables using `unwrap_or_else`.
Systemic Cause: The developer used `unwrap_or_else` on `std::env::var` for the `AETHER_UPLOAD_KEY` to prevent application crashes or for convenience during local testing, but accidentally left this insecure fallback in production code.
Auditor Note: Always check for `unwrap_or_else` and `unwrap_or` calls on environment variables representing API keys, passwords, or secrets. Ensure they fail securely rather than supplying weak default credentials.
