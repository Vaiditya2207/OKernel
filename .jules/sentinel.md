## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-04-10 - Unbounded Wait DoS in Container Execution
Vulnerability Pattern: Denial of Service via unbounded wait on untrusted execution
Systemic Cause: The execution engine (Docker manager) awaits the completion of unauthenticated user-submitted code without an explicit timeout, allowing infinite loops to hang async worker threads and exhaust resources.
Auditor Note: Always enforce strict execution timeouts using tools like tokio::time::timeout when orchestrating untrusted payloads or remote processes to prevent DoS vulnerabilities.
