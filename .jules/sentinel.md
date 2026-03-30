## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-03-30 - Missing Timeout in Docker Execution Orchestration
Vulnerability Pattern: Denial of Service (DoS) via resource exhaustion due to unbounded wait operations.
Systemic Cause: The Docker manager implementation in `syscore/src/docker/manager.rs` does not enforce a maximum execution time limit (timeout) when waiting for user-provided untrusted code execution containers to complete via `self.docker.wait_container`.
Auditor Note: Always verify that long-running async operations, especially those orchestrating untrusted inputs or external processes (e.g., waiting for containers), are wrapped with explicit timeouts like `tokio::time::timeout` to prevent indefinite hangs and resource exhaustion.
