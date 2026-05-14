## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Hardcoded Default Credentials in Aether Upload Auth
Vulnerability Pattern: Broken Authentication via hardcoded default API key fallback (`unwrap_or_else(|_| "update_me_please".to_string())`).
Systemic Cause: When retrieving secrets from environment variables, developers sometimes provide a weak default value to simplify local development or testing, which inadvertently bypasses security controls in production if the environment variable is not explicitly set.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials. Ensure they fail securely rather than supplying weak default fallbacks.
