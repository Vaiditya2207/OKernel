## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Container Execution DoS in /api/execute
Vulnerability Pattern: Missing timeout on Docker container wait (`docker.wait_container`) allowing untrusted user code to execute indefinitely.
Systemic Cause: The execution logic spawns a container for untrusted user inputs but fails to wrap the asynchronous `.await` operation for container termination with a standard `tokio::time::timeout`. As a result, infinite loops or explicit sleeps consume server resources permanently.
Auditor Note: Always ensure asynchronous operations involving untrusted input, particularly external process or container executions, are bounded by a timeout to prevent resource exhaustion and Denial of Service.
