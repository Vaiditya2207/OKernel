## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-06-11 - Weak Default Credentials in Aether File Upload
Vulnerability Pattern: Hardcoded/Weak default secrets in authentication checks.
Systemic Cause: The `upload_handler` retrieves the `AETHER_UPLOAD_KEY` environment variable but uses `unwrap_or_else` to fallback to `"update_me_please"`. This leads to a known weak credential bypassing authentication if the environment variable is not explicitly set.
Auditor Note: Always check for `unwrap_or` or `unwrap_or_else` applied to environment variables representing credentials or secrets to ensure they fail securely instead of falling back to default values.
