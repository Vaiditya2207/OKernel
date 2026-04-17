## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Execution in Code Runner
Vulnerability Pattern: Denial of Service (DoS) via unbounded wait on untrusted execution.
Systemic Cause: The `/api/execute` endpoint accepts unauthenticated code submissions and waits for the Docker container to finish without enforcing a timeout. This allows attackers to run infinite loops, indefinitely tying up server resources and connection handlers.
Auditor Note: Always verify that execution of untrusted user code or interactions with external processes/containers are wrapped with strict timeouts (e.g., `tokio::time::timeout`) to prevent resource exhaustion and DoS.
