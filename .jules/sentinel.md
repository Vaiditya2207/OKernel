## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Wait in Container Orchestration
Vulnerability Pattern: Denial of Service (DoS) via unbounded `await` on container execution (`docker.wait_container`).
Systemic Cause: The backend application acts as an orchestrator for untrusted code execution but blindly trusts that the spawned container will eventually terminate. The missing explicit timeout allows user-submitted infinite loops to run indefinitely.
Auditor Note: Always verify that any function awaiting external processes, containers, or untrusted code execution uses explicit timeouts (e.g., `tokio::time::timeout`) to prevent resource exhaustion and DoS.
