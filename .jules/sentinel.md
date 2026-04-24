## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Missing Timeout in Container Execution
Vulnerability Pattern: Missing explicit timeout on untrusted execution wait loops (e.g., `docker.wait_container`).
Systemic Cause: The `execute` function in `syscore/src/docker/manager.rs` does not enforce an explicit timeout when waiting for a Docker container to complete execution. This omission allows submitted code with infinite loops to run indefinitely and exhaust system resources.
Auditor Note: Always check for missing bounds and timeouts when interacting with external processes or Docker APIs. When orchestrating untrusted code, ensure mechanisms like `tokio::time::timeout` are enforced to prevent unbounded waits and DoS vulnerabilities.
