## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-19 - Broken Auth via Insecure Default Fallbacks
Vulnerability Pattern: Hardcoded weak default credentials used when environment variables are missing (`unwrap_or_else`).
Systemic Cause: Developers attempting to make local testing or initial setup easier by providing default fallback credentials instead of failing securely when required secrets are missing in production.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on `std::env::var` calls representing secrets or credentials, ensuring they fail securely rather than supplying weak defaults.
