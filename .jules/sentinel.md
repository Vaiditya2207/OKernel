## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-24 - Aether Upload Handler Vulnerabilities
Vulnerability Pattern: Arbitrary File Write via unsanitized multipart filenames and Broken Auth via weak default fallback credentials.
Systemic Cause: The `upload_handler` in `syscore/src/server/aether.rs` uses `unwrap_or_else` to supply a weak default API key (`update_me_please`) when `AETHER_UPLOAD_KEY` is missing. Additionally, user-supplied filenames from multipart fields are passed directly to `PathBuf::join` without sanitization.
Auditor Note: Always check for `unwrap_or_else` on environment variables for secrets, and verify that all user-controlled filenames are sanitized using `Path::new(&filename).file_name()` before being used in file system operations.
