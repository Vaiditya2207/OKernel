## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded execution of untrusted code in Docker manager
Vulnerability Pattern: Missing execution timeout on remote/untrusted code execution via `wait_container`.
Systemic Cause: Trusting user-submitted code to naturally terminate. While memory/CPU bounds are present in `HostConfig`, the lack of wall-clock timeouts for execution jobs enables attackers to hoard running container instances and exhaust host resources or connection concurrency limits over time.
Auditor Note: Always check usages of unbounded `.await` on external processes, tasks, or API calls, particularly those executing user-provided logic or interacting with Docker. Ensure an explicit timeout (e.g., `tokio::time::timeout`) is used and accompanied by reliable cleanup code (e.g., forcing a process kill).
