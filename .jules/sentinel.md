## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Weak Default Credential in Aether File Upload
Vulnerability Pattern: Broken Authentication / Hardcoded Fallback Secret.
Systemic Cause: The application uses `unwrap_or_else` to supply a weak default credential (`update_me_please`) when the expected environment variable for the API key (`AETHER_UPLOAD_KEY`) is missing. This bypasses secure-by-default principles by failing open rather than failing securely (e.g., denying access or crashing on startup).
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets, credentials, or keys to ensure they do not introduce weak default fallbacks that an attacker could guess.
