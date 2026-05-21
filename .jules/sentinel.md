## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-21 - Weak Default Credentials in Auth Fallbacks
Vulnerability Pattern: Using `unwrap_or_else` or `unwrap_or` with hardcoded weak strings when environment variables for secrets/keys are missing.
Systemic Cause: In `upload_handler`, `AETHER_UPLOAD_KEY` has a fallback of `update_me_please`. This creates a systemic broken authentication issue if the environment variable is not explicitly set in production.
Auditor Note: Always check usages of `std::env::var` for sensitive keys. Ensure they fail securely (e.g., returning an error or panicking during startup) rather than providing a default weak string.
