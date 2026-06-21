## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2025-02-17 - Missing Timeout on Untrusted Code Execution
Vulnerability Pattern: Denial of Service via Resource Exhaustion (Infinite Loop).
Systemic Cause: The `execute` handler in `syscore/src/docker/manager.rs` spawns a Docker container and awaits its completion unbounded (`wait_container().next().await`). Untrusted user code is not subjected to an explicit timeout.
Auditor Note: Always ensure that execution of untrusted code, shell commands, or container processes is wrapped with an explicit timeout mechanism (like `tokio::time::timeout`) to prevent malicious or accidental resource exhaustion.
