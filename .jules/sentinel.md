## 2025-02-20 - Arbitrary File Write in SysCore Aether Upload
Vulnerability Pattern: Path Traversal in File Upload + Hardcoded Default Credential
Systemic Cause: Lack of input validation on filename parameter in multipart upload handler. Fallback to insecure default for authentication.
Auditor Note: Review all file operations involving user-supplied paths. Check for default credentials in environment variable handling.
