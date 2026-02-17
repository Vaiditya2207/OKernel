## 2024-05-22 - Arbitrary File Write in Aether Upload
Vulnerability Pattern: Path Traversal in Multipart Filename
Systemic Cause: Lack of input sanitization for filenames in file upload handler.
Auditor Note: Always validate `filename` from multipart uploads before using them in file paths.
