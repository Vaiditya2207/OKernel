## 2025-05-24 - SysCore File Upload Vulnerability
Vulnerability Pattern: Unsanitized User Input in File Operations
Systemic Cause: The `upload_handler` in `syscore` trusts the `filename` provided in the multipart request without sanitization, leading to arbitrary file write via path traversal.
Auditor Note: Always verify that file paths constructed from user input are sanitized using `Path::file_name()` or similar mechanisms to strip directory components. Check for direct usage of `PathBuf::join` with user-controlled strings.
