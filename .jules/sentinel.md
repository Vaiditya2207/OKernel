## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Weak Default Fallback for Missing Credentials
Vulnerability Pattern: A critical security check falls back to a hardcoded weak string ("update_me_please") when the intended environment variable is missing using `unwrap_or_else`.
Systemic Cause: Developer convenience or local testing setups leaking into production pathways without failing securely upon missing configuration.
Auditor Note: Systematically verify all usages of `std::env::var("...").unwrap_or_else` or `unwrap_or` for secrets. Missing credentials must fail closed (deny access or panic at startup) rather than supplying a vulnerable default.
