## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Wait on Untrusted Container Execution
Vulnerability Pattern: Missing timeout when waiting for async operations involving user-controlled code execution (e.g., `docker.wait_container`).
Systemic Cause: The execution pipeline in `syscore/src/docker/manager.rs` does not enforce strict timeouts on the untrusted workload container, assuming the workload will naturally complete. This causes the async task to hang indefinitely if the user submits an infinite loop.
Auditor Note: Always verify that any operations executing untrusted code or container workloads use explicit timeouts (e.g., `tokio::time::timeout` in Rust) to prevent unauthenticated Denial of Service via resource exhaustion.
