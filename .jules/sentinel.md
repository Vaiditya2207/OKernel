## 2024-05-24 - File Upload Path Traversal
Vulnerability Pattern: Unsanitized File Name in Multipart Upload
Systemic Cause: The `axum::extract::Multipart` extractor does not automatically sanitize filenames, leaving it to the developer. The application logic trusted `filename` directly from the multipart header without validation.
Auditor Note: Always check file upload handlers for path sanitization. Specifically look for usage of `Path::new(untrusted_input).join(...)` or direct file creation using untrusted names. Ensure filenames are stripped to their basename using `file_name()`.
