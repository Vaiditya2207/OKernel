## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-18 - Broken Authentication in Aether File Upload
Vulnerability Pattern: Weak default credential fallback via `unwrap_or_else` on `std::env::var`.
Systemic Cause: The `upload_handler` uses a hardcoded default API key ("update_me_please") if `AETHER_UPLOAD_KEY` is not present in the environment. This makes the system silently vulnerable by default.
Auditor Note: Look for `unwrap_or_else` or `unwrap_or` used with environment variables that represent secrets.
