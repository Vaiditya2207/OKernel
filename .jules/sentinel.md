## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Fallback Secret in Aether Upload
Vulnerability Pattern: Hardcoded Secret/Weak Default Fallback. The code uses `unwrap_or_else` to supply a weak default string ("update_me_please") when a critical environment variable (`AETHER_UPLOAD_KEY`) is missing.
Systemic Cause: Lack of fail-secure initialization. Developers used fallback defaults for convenience during development, allowing the production application to start in an insecure state if not configured properly.
Auditor Note: Always check logic flows handling environment variables, especially `unwrap_or_else` or `unwrap_or` for secrets. Missing configuration for security-critical parameters must fail securely (e.g., exit or panic) rather than substituting insecure defaults.
