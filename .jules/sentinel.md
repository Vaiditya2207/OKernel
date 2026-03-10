## 2026-02-21 - Critical Architectural Flaw: Weak Default Credentials & Unsanitized File Paths

Vulnerability Pattern: Hardcoded default API keys in source code combined with unsanitized file path inputs in file upload handlers.

Systemic Cause: The `syscore` backend relies on environment variables for security (API Key) but provides a fallback default value ("update_me_please") that is insecure for production. Additionally, the file upload handler validates the `version` path component but fails to validate the `filename` component extracted from multipart form data, assuming it is safe. This indicates a lack of "Defense in Depth" and reliance on happy-path assumptions.

Auditor Note: Future scans should prioritize checking all file system operations for proper path sanitization, especially when user input (filenames, paths) is involved. Also, scan for other instances of default credentials or secrets in the codebase.
