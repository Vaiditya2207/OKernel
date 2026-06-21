## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-03-26 - Missing Timeout in Container Manager Execution
Vulnerability Pattern: Denial of Service (DoS) via Unbounded Async Await in `docker.wait_container`.
Systemic Cause: The system trusts unauthenticated user-provided code (e.g., Python `while True: pass`) to complete in a finite time without enforcing server-side process execution timeouts. The `docker.wait_container` async call will hang forever on an infinite loop, stranding both the container and the Rust task.
Auditor Note: Always enforce explicit timeouts with `tokio::time::timeout` when awaiting long-running, untrusted, or user-orchestrated resources, such as external processes, API calls, or Docker container executions.
