## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Container Wait in Execution Endpoint
Vulnerability Pattern: Denial of Service (DoS) via unbounded asynchronous wait (`docker.wait_container`) when executing untrusted user code.
Systemic Cause: The server delegates execution to Docker but assumes the container will eventually exit. Because there is no explicit timeout wrapping the asynchronous wait operation, infinite loops in untrusted code will stall the container and the awaiting task indefinitely, leading to resource exhaustion.
Auditor Note: When orchestrating untrusted code or container runs, always use explicit timeouts like `tokio::time::timeout` to prevent unbounded wait and resource exhaustion vulnerabilities.
