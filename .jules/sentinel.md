## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Missing Timeout in Container Execution (DoS)
Vulnerability Pattern: Unbounded wait on untrusted process execution (`docker.wait_container`).
Systemic Cause: The system trusts that user-provided code submitted to the `/api/execute` endpoint will terminate on its own, missing an explicit overarching execution timeout for the spawned Docker container.
Auditor Note: When orchestrating untrusted code or container runs, always look for explicit timeouts (e.g., `tokio::time::timeout`) to prevent resource exhaustion and Denial of Service (DoS) vulnerabilities caused by infinite loops or deadlocks.
