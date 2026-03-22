## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded wait_container in Docker Manager
Vulnerability Pattern: Denial of Service (DoS) via unbounded waits on untrusted container execution.
Systemic Cause: The `execute` function relies on `docker.wait_container().next().await` without any timeout, allowing attackers to submit infinite loop code payloads that tie up backend tokio tasks and docker container resources indefinitely.
Auditor Note: Always verify that operations interacting with untrusted code or remote container resources (like `wait_container`) use explicit timeouts, such as `tokio::time::timeout`, to prevent unbounded wait and resource exhaustion vulnerabilities.
