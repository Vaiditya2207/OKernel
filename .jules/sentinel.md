## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-04-15 - Missing Execution Timeout Leads to Denial of Service
Vulnerability Pattern: Missing timeout in `docker.wait_container`.
Systemic Cause: The execution engine spawns bespoke containers for unauthenticated users but uses unbounded waits, allowing infinite loops in user code to run indefinitely and exhaust server resources.
Auditor Note: Always explicitly enforce timeouts for container execution using tools like `tokio::time::timeout`, especially when orchestrating untrusted code.
