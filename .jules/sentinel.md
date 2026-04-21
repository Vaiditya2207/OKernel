## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Asynchronous Wait in Untrusted Code Execution
Vulnerability Pattern: Denial of Service (DoS) via unbounded asynchronous wait (`docker.wait_container`) without a timeout.
Systemic Cause: When executing untrusted user-submitted code in an isolated container environment, the system trusts the container to eventually terminate. However, if the code runs an infinite loop or blocks indefinitely, the `wait_container` future never completes, causing the backend to hang and potentially exhaust asynchronous task slots and server resources.
Auditor Note: Always verify that asynchronous waits involving external processes or untrusted code execution are bounded by strict timeouts (e.g., using `tokio::time::timeout`). Look for missing timeout handling on operations like `wait_container`, process wait, or network requests targeting external systems.
