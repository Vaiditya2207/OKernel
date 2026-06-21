## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-19 - Unbounded Container Wait Exhaustion DoS
Vulnerability Pattern: Missing Timeout in `docker.wait_container` leading to Denial of Service.
Systemic Cause: The execution logic in `syscore/src/docker/manager.rs` does not impose any execution time limits on containers running user-submitted code via the unauthenticated `/api/execute` endpoint. Malicious code (e.g., infinite loops) will cause the Rust server thread to block indefinitely waiting for the container, exhausting server resources.
Auditor Note: When orchestrating untrusted code or container runs, always verify the presence of explicit timeouts (e.g., `tokio::time::timeout`) to prevent unbounded wait operations and resource exhaustion vulnerabilities.
