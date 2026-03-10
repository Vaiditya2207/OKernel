## 2024-02-14 - Arbitrary File Write via Path Traversal in SysCore
Vulnerability Pattern: Path Traversal (CWE-22) in Multipart Filename Handling
Systemic Cause: Lack of input sanitization for user-provided filenames when writing to disk. The `syscore` backend assumes filenames from `multipart/form-data` are safe to use directly in `PathBuf::join`, which is incorrect as they can contain directory traversal sequences or be absolute paths.
Auditor Note: Always verify that any file path construction using user input (filenames, IDs, etc.) is strictly validated to be within the intended directory. Use `Path::file_name()` or similar methods to strip directory components. Check for hardcoded default credentials in environment variable fallbacks.
