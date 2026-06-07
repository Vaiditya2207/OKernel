## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-06-07 - Weak Default Fallback in Aether Upload Auth
Vulnerability Pattern: Broken Auth via weak default credential in `unwrap_or_else` on environment variable.
Systemic Cause: The application uses `unwrap_or_else` on `std::env::var` for the `AETHER_UPLOAD_KEY` secret, supplying a hardcoded fallback (`"update_me_please"`) instead of failing securely when the environment variable is missing. This violates the Fail-Safe Default principle.
Auditor Note: Always check for `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials to ensure they do not introduce weak defaults.
