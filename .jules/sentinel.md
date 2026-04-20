## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.
## 2026-03-18 - Missing Timeout in Container Execution (DoS)
Vulnerability Pattern: Unbounded resource allocation via missing execution timeout in Docker container waiting logic.
Systemic Cause: The Docker manager implementation assumes normal code execution flow and fails to account for malicious edge cases, like infinite loops. It trusts the client-provided input to terminate eventually, lacking defense-in-depth resource bounding.
Auditor Note: Always verify that interactions with asynchronous tasks, especially those depending on external processes (e.g., Docker `wait_container`, shell execution), are wrapped in timeout bounds. A failure to bound execution time can directly lead to Denial of Service via resource exhaustion.
