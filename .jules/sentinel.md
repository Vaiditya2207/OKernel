## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-03-31 - Missing Timeout on Docker Container Wait
Vulnerability Pattern: Unbounded wait on untrusted container execution leading to Denial of Service (DoS).
Systemic Cause: The `ContainerManager::execute` function in `syscore/src/docker/manager.rs` spawns an ephemeral Docker container and calls `docker.wait_container` without a timeout (like `tokio::time::timeout`). Untrusted user code (e.g., an infinite loop) sent to `/api/execute` will cause the backend thread to wait indefinitely, exhausting resources.
Auditor Note: Always use explicit timeouts when orchestrating untrusted code or container runs (e.g., via `docker.wait_container`) to prevent unbounded wait and resource exhaustion (DoS) vulnerabilities.
