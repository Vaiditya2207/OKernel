## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Broken Auth: Weak Default Credential for Aether Upload API
Vulnerability Pattern: Broken Auth due to weak default credential fallback in environment variables.
Systemic Cause: The system uses `unwrap_or_else` on `std::env::var("AETHER_UPLOAD_KEY")` and provides a weak default string instead of failing securely when the environment variable is absent.
Auditor Note: Always check for `unwrap_or_else` or `unwrap_or` on environment variables that represent secrets or credentials. Ensure they fail securely rather than supplying weak default fallbacks.
