## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-20 - Unbounded Wait in Container Execution
Vulnerability Pattern: Denial of Service (DoS) via missing timeout enforcement.
Systemic Cause: The `ContainerManager::execute` method in `syscore/src/docker/manager.rs` spawns an ephemeral Docker container and waits for its exit via `docker.wait_container`. Because the wait is unbounded (i.e., no use of `tokio::time::timeout`), untrusted payloads like infinite loops will never exit and hang the backend connection indefinitely while consuming server resources.
Auditor Note: Always ensure that blocking or waiting operations (such as waiting on network operations, external processes, or Docker containers) on untrusted inputs or tasks enforce explicit timeouts. Look for calls like `wait`, `wait_container`, or long-running stream collections without wrappers like `tokio::time::timeout`.