## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-04-20 - Broken Auth and Path Injection in Aether Upload
Vulnerability Pattern: Chained weak default API key with Arbitrary File Write via absolute path injection.
Systemic Cause: The upload handler fails to enforce strict API key presence and blindly trusts user-supplied filenames via `multipart.next_field().file_name()`.
Auditor Note: Always verify default fallback behaviors for critical secrets and ensure unsanitized user inputs are never passed to `PathBuf::join`.
