## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Default Fallback Secret in Aether Upload
Vulnerability Pattern: A weak, hardcoded string ("update_me_please") is used as a fallback for the critical `AETHER_UPLOAD_KEY` environment variable in `syscore/src/server/aether.rs`.
Systemic Cause: The developers used `unwrap_or_else` to supply a default value instead of failing securely when a critical environment variable for authentication is missing. This introduces a Broken Authentication vulnerability by falling back to a known weak key instead of denying access.
Auditor Note: Always identify usages of `unwrap_or_else` or `unwrap_or` that supply weak default fallback secrets or credentials instead of failing securely when critical environment variables are missing.
