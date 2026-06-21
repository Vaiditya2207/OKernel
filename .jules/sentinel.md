## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-20 - Unbounded Wait in Docker Container Execution
Vulnerability Pattern: Denial of Service (DoS) via resource exhaustion due to missing execution timeouts.
Systemic Cause: The `/api/execute` endpoint takes untrusted user code and runs it in an ephemeral Docker container via `syscore/src/docker/manager.rs`. However, `docker.wait_container().next().await` is called without any `tokio::time::timeout` wrapper. This allows an attacker to submit an infinite loop (e.g. `while True: pass`), causing the async task to wait indefinitely and eventually exhausting server resources.
Auditor Note: When auditing execution of untrusted code or container runs, always verify that asynchronous wait operations or blocking calls are bound by an explicit timeout. Look for `await` on container/process futures without a `timeout(...)` wrapper.