## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-06-01 - Hardcoded Fallback Credential in Aether Server
Vulnerability Pattern: Broken Auth via weak default fallback credential (`unwrap_or_else` on environment variables).
Systemic Cause: In `syscore/src/server/aether.rs`, the `upload_handler` uses `unwrap_or_else` on an environment variable (`AETHER_UPLOAD_KEY`) representing a secret. This supplies a weak default ("update_me_please") instead of failing securely when the environment is misconfigured.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials in Rust, ensuring they fail securely rather than supplying weak defaults.
