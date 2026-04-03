## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Wait in Docker Execution
Vulnerability Pattern: Denial of Service (DoS) via unbounded wait (`docker.wait_container`) without a timeout.
Systemic Cause: The execution engine spawns ephemeral Docker containers to run untrusted, arbitrary code but relies on the container itself to exit naturally. There is no timeout enforced on the async wait operation, allowing infinite loops in user code to hold execution resources indefinitely.
Auditor Note: Always ensure that operations executing untrusted code or external processes (especially Docker or OS-level commands) are wrapped with explicit timeouts (e.g., `tokio::time::timeout`) to prevent resource exhaustion and Denial of Service.
