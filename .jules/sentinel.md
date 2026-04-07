## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-18 - Missing Timeout in Container Execution (DoS)
Vulnerability Pattern: Unbounded wait on external resource execution (`docker.wait_container`) leading to Denial of Service.
Systemic Cause: The `/api/execute` endpoint orchestrates untrusted code execution using bespoke Docker containers. However, the wait loop on container exit does not impose a maximum timeout. Since malicious code (e.g., an infinite loop) could run forever, it can permanently tie up worker threads and exhaust server resources.
Auditor Note: Always verify that interactions with untrusted code execution or third-party containers utilize explicit timeouts (e.g., `tokio::time::timeout`) to prevent unbounded waiting and resource exhaustion.