## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Broken Auth via Weak Default Credential
Vulnerability Pattern: Insecure default fallback for critical secrets via `unwrap_or_else()`.
Systemic Cause: The upload handler attempts to read `AETHER_UPLOAD_KEY` from the environment but provides a hardcoded, weak default value ("update_me_please") if the variable is missing. This violates the fail-safe default principle and leads to widespread broken authentication if deployments forget to set the environment variable.
Auditor Note: Systematically check for uses of `unwrap_or_else` or `unwrap_or` on environment variables representing secrets or credentials, ensuring they fail securely rather than supplying weak default fallbacks.
