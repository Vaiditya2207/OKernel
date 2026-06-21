## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-19 - Unbounded Wait (DoS) in Docker Execution
Vulnerability Pattern: Denial of Service (DoS) via unbounded wait during untrusted code execution.
Systemic Cause: The `ContainerManager::execute` function calls `docker.wait_container` without a timeout wrapper. This allows malicious user-submitted code containing infinite loops to run indefinitely and exhaust server resources.
Auditor Note: Always ensure explicit timeouts (e.g., `tokio::time::timeout`) are used when orchestrating untrusted code or container runs to prevent unbounded execution and resource exhaustion.