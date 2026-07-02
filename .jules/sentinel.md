## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Fallback Credential in Aether Upload Handler
Vulnerability Pattern: Weak default credential used as a fallback for missing environment variable `AETHER_UPLOAD_KEY`.
Systemic Cause: The `upload_handler` attempts to handle the absence of the required API key by providing a default value (`"update_me_please"`) via `unwrap_or_else`, prioritizing service availability (or ease of development) over security.
Auditor Note: Always check usages of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials. Ensure they fail securely rather than supplying weak default fallbacks that can be exploited in production.
