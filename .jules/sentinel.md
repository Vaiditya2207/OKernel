## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2024-05-18 - Unbounded Docker Container Wait DoS
Vulnerability Pattern: Unbounded Wait/Missing Timeout in `docker.wait_container`.
Systemic Cause: The execution logic in `syscore/src/docker/manager.rs` spawns a container to run untrusted code but uses `.next().await` on the stream returned by `docker.wait_container` without wrapping it in a timeout (e.g., `tokio::time::timeout`). An attacker can submit an infinite loop, causing the backend to wait indefinitely, exhausting resources and workers.
Auditor Note: Always check for missing timeouts when orchestrating or waiting on untrusted processes/containers, especially when invoked from unauthenticated endpoints like `/api/execute`.
