## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2026-03-25 - Unbounded Wait leading to Denial of Service in Container Execution
Vulnerability Pattern: Unbounded Wait / Resource Exhaustion via missing timeout on user code execution.
Systemic Cause: User-submitted code is executed inside a Docker container, but the `.await` on the container's exit future `self.docker.wait_container::<String>(&id, None).next().await` lacks a timeout wrapper. This allows infinite loops in user code to run indefinitely, tying up system and Docker resources.
Auditor Note: Always verify that untrusted processes or remote invocations enforce strict timeouts (e.g., using `tokio::time::timeout`) when yielding or waiting to avoid resource exhaustion and Denial of Service (DoS) attacks.