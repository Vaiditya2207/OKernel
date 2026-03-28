## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Container Execution DoS
Vulnerability Pattern: Missing timeout in async wait operation (`self.docker.wait_container::<String>(&id, None).next().await`).
Systemic Cause: The execution engine trusts that user-submitted code (Python/C++) will eventually terminate. By omitting a strict timeout on the container execution wait block, malicious payloads (e.g., `while True: pass`) can run indefinitely, consuming server resources and blocking threads.
Auditor Note: When auditing execution pipelines or orchestrators dealing with untrusted code, always verify the presence of explicit timeouts (e.g., `tokio::time::timeout`) wrapping container waits or process outputs.
