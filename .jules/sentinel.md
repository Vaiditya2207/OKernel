## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-03-17 - Unbounded Docker Container Wait
Vulnerability Pattern: Denial of Service (DoS) via Infinite Loops in User Code.
Systemic Cause: The backend API endpoint `/api/execute` runs arbitrary user code in a bespoke container but uses `docker.wait_container` without a timeout in `syscore/src/docker/manager.rs`. Any infinite loop submitted by a user will block the async executor task and keep the container running indefinitely, eventually exhausting system resources (CPU/Memory).
Auditor Note: Always verify that external process/container execution features include strict, enforced timeouts to prevent DoS attacks.
