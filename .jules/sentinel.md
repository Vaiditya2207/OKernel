## 2024-05-24 - Arbitrary File Write in Aether Uploads
Vulnerability Pattern: Unsanitized filenames from multipart form data allow path traversal.
Systemic Cause: Lack of validation when joining user-provided filenames with base paths in `upload_handler`.
Auditor Note: Always verify path sanitization when handling file uploads or joining user inputs with file paths.
