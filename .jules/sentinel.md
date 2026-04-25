## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2024-05-18 - Unbounded Wait DoS in Container Execution
Vulnerability Pattern: Denial of Service (DoS) via unbounded asynchronous wait (`await`) on untrusted container execution.
Systemic Cause: The execution logic in `syscore/src/docker/manager.rs` assumes that user-submitted code will eventually terminate. By not wrapping the wait operation in an explicit timeout, the system becomes vulnerable to infinite loops or blocking code, leading to resource exhaustion.
Auditor Note: Always ensure that operations processing untrusted data or executing untrusted code have strict bounds on execution time and resource limits. Look for `await` on potentially unbounded futures, particularly those interacting with external processes or network calls.
