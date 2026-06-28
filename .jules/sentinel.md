## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-06-28 - Weak Default Credential Fallback in Aether File Upload
Vulnerability Pattern: Broken Auth via hardcoded weak default credential fallback.
Systemic Cause: The `upload_handler` in `syscore/src/server/aether.rs` uses `std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string())`. If the environment variable is missing (which might easily happen in dev/test or misconfigured production), the system allows authentication using a known, hardcoded string.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials, ensuring they fail securely rather than supplying weak default fallbacks.
