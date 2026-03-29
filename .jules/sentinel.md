## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-18 - Missing Timeout in Container Execution
Vulnerability Pattern: Unbounded Wait/Resource Exhaustion (Denial of Service).
Systemic Cause: The `/api/execute` endpoint orchestrates untrusted code execution via Docker containers but fails to enforce a maximum execution duration (timeout) on `docker.wait_container`. Because user-submitted code can loop indefinitely, the server resources (CPU, memory limits, and container instance slots) can be permanently exhausted.
Auditor Note: Always check for explicit timeouts (e.g., `tokio::time::timeout`) when interacting with external processes or Docker containers running untrusted user payloads.
