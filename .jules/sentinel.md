## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-06-08 - Weak Default Credentials in Aether Upload Auth
Vulnerability Pattern: Broken Auth via weak default fallback on missing environment variables.
Systemic Cause: The `upload_handler` uses `unwrap_or_else` on `std::env::var("AETHER_UPLOAD_KEY")` to supply a weak default credential ("update_me_please") instead of securely failing when the key is missing.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials to ensure they fail securely.
