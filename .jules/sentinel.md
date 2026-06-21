## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-18 - Unbounded Docker Wait Container in Code Execution
Vulnerability Pattern: Denial of Service (DoS) via unbounded wait without a timeout on untrusted execution (`docker.wait_container`).
Systemic Cause: The server waits indefinitely for a user-submitted script to complete its execution inside a Docker container without utilizing `tokio::time::timeout`. Malicious code containing infinite loops can thus block resources and eventually exhaust concurrent execution threads or memory.
Auditor Note: Always verify that any function orchestrating untrusted code or container runs (e.g., `docker.wait_container`, `Command::wait`, etc.) is wrapped in an explicit timeout to prevent unbounded waits.