# Sentinel Journal

## 2026-02-19 - Unsanitized User Input in File Operations
Vulnerability Pattern: Unsanitized Filenames in File Writes
Systemic Cause: The application blindly trusts filenames provided by the client (e.g., in multipart uploads) and uses them to construct file paths for writing. This allows attackers to perform path traversal (`../`) and write files to arbitrary locations on the server.
Auditor Note: In future scans, look for any file system operations that use user-supplied strings as part of the path without sanitization (e.g., `Path::join` without canonicalization or validation). Also, ensure that default credentials (like "update_me_please") are removed or disabled in production builds.
