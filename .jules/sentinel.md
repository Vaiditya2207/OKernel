## 2024-05-01 - Arbitrary File Write in PathBuf::join
Vulnerability Pattern: Unsanitized user input extracted from multipart requests is passed directly to `PathBuf::join`.
Systemic Cause: Lack of boundary validation and misunderstanding of Rust's `Path::join` behavior (where absolute paths replace the base path).
Auditor Note: Always audit uses of `PathBuf::join` involving user-supplied strings, especially those originating from file uploads or HTTP headers. Ensure `.file_name()` sanitization is applied.
