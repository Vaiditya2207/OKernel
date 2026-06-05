## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Default Credentials in Authentication
Vulnerability Pattern: Broken Auth via weak default fallback for API Key (`unwrap_or_else(|_| "update_me_please".to_string())`).
Systemic Cause: The `upload_handler` attempts to be robust by providing a fallback if the environment variable `AETHER_UPLOAD_KEY` is not set, unintentionally hardcoding a highly guessable credential in production code.
Auditor Note: Always audit `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials. Ensure they fail securely rather than supplying weak default fallbacks.
