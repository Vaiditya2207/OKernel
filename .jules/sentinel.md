## 2026-04-02 - Missing Timeout in Container Execution (DoS)
Vulnerability Pattern: Unbounded wait on a container executing user-supplied code via `docker.wait_container`.
Systemic Cause: The execution engine trusts that user code will eventually terminate. By failing to wrap `docker.wait_container` in a strict timeout (e.g., `tokio::time::timeout`), malicious code (like infinite loops) can run indefinitely and exhaust server resources.
Auditor Note: Always ensure that any external process or container spawned to execute untrusted input is bound by a strict, non-bypassable timeout to prevent Resource Exhaustion and Denial of Service.

## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.