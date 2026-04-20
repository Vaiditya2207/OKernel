## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Missing Timeout on Docker Container Execution
Vulnerability Pattern: Unbounded Wait / Resource Exhaustion (DoS). The `syscore/src/docker/manager.rs` does not bound its wait when awaiting untrusted user code execution in Docker containers.
Systemic Cause: `docker.wait_container` returns a stream that never yields if the underlying process does not terminate (e.g. infinite loops), leading to suspended futures that never resolve and a rapid depletion of system and Docker resources.
Auditor Note: In systems orchestrating untrusted code or container runs, always verify the presence of explicit, strict timeouts using `tokio::time::timeout` or similar wrappers. Lack of timeouts is a prime DoS vulnerability vector.
