## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-19 - Unbounded Docker wait_container Resource Exhaustion
Vulnerability Pattern: Missing Timeout on Container Execution (`docker.wait_container`).
Systemic Cause: The `/api/execute` endpoint relies on the Docker container manager to run user-provided code, but awaits the container's completion without an explicit time limit. Malicious or bugged code (like an infinite loop) causes the async task to hang indefinitely, tying up system resources.
Auditor Note: Always enforce explicit timeouts (`tokio::time::timeout`) when awaiting operations on untrusted execution environments or external processes.
