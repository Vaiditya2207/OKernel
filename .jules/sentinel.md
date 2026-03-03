## 2024-05-24 - Arbitrary File Write via Unsafe PathBuf Construction in axum Multipart

Vulnerability Pattern: The application extracts the `filename` from a multipart form using `axum::extract::Multipart` (`field.file_name()`) and passes it directly to `std::path::PathBuf::join()` without sanitization.

Systemic Cause: The standard library `PathBuf::join` function inherently behaves dynamically: it replaces the entire current path if the joined string is an absolute path. There is a false assumption that standard HTTP frameworks automatically sanitize filenames from user uploads, leaving the system susceptible to relative path traversal and absolute path overwrites.

Auditor Note: In future code scans, particularly in Rust implementations using HTTP frameworks (e.g., Axum, Actix, Rocket), prioritize auditing all file upload routes. Check if `file_name()` extraction points are safely wrapped, sanitized (such as retaining only the basename or stripping traversal characters), and verify if a unique, generated identifier should be used instead of untrusted user input before passing it into file I/O operations.