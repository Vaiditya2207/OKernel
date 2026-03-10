## 2024-05-24 - Arbitrary File Write via Unsanitized Multipart Filename
Vulnerability Pattern: Unsanitized filename from `axum::extract::Multipart` is directly used with `PathBuf::join`, allowing arbitrary file write and path traversal (e.g., via absolute paths or `../`).
Systemic Cause: The `syscore` backend trusts the `filename` provided by the client in the multipart form data without any validation or sanitization before appending it to the base storage directory.
Auditor Note: In future Rust codebase scans, specifically look for `PathBuf::join` being used with user-provided input, especially filenames extracted from multipart forms, as `PathBuf::join` will completely replace the base path if the provided input is an absolute path.
