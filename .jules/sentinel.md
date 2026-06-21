## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Missing Timeout in Docker Execution Container
Vulnerability Pattern: Denial of Service (DoS) via Infinite Loop execution due to lack of timeout in `docker.wait_container`.
Systemic Cause: The backend accepts arbitrary user code and uses an `async` wait (`self.docker.wait_container::<String>(&id, None).next().await;`) that hangs indefinitely if the executed code loops endlessly. No runtime constraint bounds the maximum allowable execution duration.
Auditor Note: Always check for missing timeouts, bounded retries, or unrestricted loops/waits when processing untrusted, user-supplied content, especially in network requests or sandboxed executions.
