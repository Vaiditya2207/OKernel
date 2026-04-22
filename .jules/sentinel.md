## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Missing Timeout in Container Execution
Vulnerability Pattern: Denial of Service via unbounded future execution on untrusted input.
Systemic Cause: The execution logic in `docker.wait_container` correctly spawns an ephemeral container with memory constraints, but inherently trusts that the executing code will eventually terminate. The async code completely relies on the external process stopping, failing to provide an application-level timeout boundary.
Auditor Note: Always verify that unbounded operations, especially those orchestrating untrusted external resources or containers, are wrapped with explicit timeouts (e.g., `tokio::time::timeout`) to ensure resource availability.
