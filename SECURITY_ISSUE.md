# 🛡️ CRITICAL Data Leakage / Arbitrary File Write: Unsanitized Filename in Aether Uploads

## 🚨 Severity
CRITICAL

## 💡 Description
The `/api/v1/aether` upload endpoint in `syscore/src/server/aether.rs` contains a critical path traversal and arbitrary file write vulnerability. The issue stems from the `upload_handler` function, which extracts the filename from an `axum::extract::Multipart` field using `field.file_name()` and joins it directly to a base directory (`version_dir`) using `PathBuf::join` without prior sanitization.

In Rust, `std::path::PathBuf::join` replaces the entire base path if the appended path is absolute (e.g., starting with `/`). Even if it's not absolute, if the filename contains directory traversal sequences (e.g., `../../../etc/passwd`), the resulting path will resolve outside the intended storage directory.

Affected Code: `syscore/src/server/aether.rs`, lines ~108-142:
```rust
let mut filename: Option<String> = None;
// ... (multipart parsing loop) ...
        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
// ...
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```
Because the `filename` variable is derived directly from the user-controlled multipart request and is not validated or sanitized, an attacker can specify an arbitrary path for the uploaded file content.

Additionally, this service suffers from a Broken Auth issue as the `AETHER_UPLOAD_KEY` falls back to `update_me_please` if not set, making exploitation significantly easier.

## 🎯 Potential Impact
An attacker can overwrite critical system files or upload malicious executables to arbitrary locations on the host file system. This could lead to Remote Code Execution (RCE) (e.g., by overwriting authorized SSH keys, cron jobs, or the server executable itself) or a complete system compromise. The ability to write anywhere on the filesystem as the process owner represents a critical risk.

## 🛠️ Steps to Reproduce
1. Prepare a malicious multipart form-data payload with the `file` field containing a filename crafted for path traversal, such as `../../../../../../../../tmp/pwned.txt`. Note: A valid version (e.g., "1.0.0") is required to pass the initial validation.
2. Ensure you have the default fallback key `update_me_please` or a valid `AETHER_UPLOAD_KEY`.
3. Send a POST request to `/api/v1/aether/upload` (or the equivalent mounted endpoint for `upload_handler`) with the payload:

```http
POST /api/v1/aether/upload HTTP/1.1
Host: localhost:3001
Authorization: Bearer update_me_please
Content-Type: multipart/form-data; boundary=------------------------boundary123

--------------------------boundary123
Content-Disposition: form-data; name="version"

1.0.0
--------------------------boundary123
Content-Disposition: form-data; name="file"; filename="../../../../../../../../tmp/pwned.txt"
Content-Type: text/plain

malicious content here
--------------------------boundary123--
```

4. Observe that the file is written to `/tmp/pwned.txt` (or an equivalent location depending on the current working directory of the process) instead of the intended `storage/aether/1.0.0/` directory.

## ✅ Recommended Remediation
1. **Sanitize the Filename:** Do not trust the filename provided by the client. Extract only the final component (the file name itself) and verify it does not contain dangerous characters. You can use the `std::path::Path::file_name` method or sanitize it heavily to ensure it resolves strictly within the intended directory.
```rust
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;

// Additional validation against ".." or "/" if necessary, though file_name() often handles this
```
2. **Path Normalization and Validation:** After joining, you can optionally resolve the path fully (`fs::canonicalize`) and ensure it still starts with the intended base directory before writing.
3. **Remove Default Key:** Remove the fallback to `update_me_please`. If the `AETHER_UPLOAD_KEY` environment variable is absent, the application should either fail to start or reject all upload requests.

## 🔗 References
*   [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
*   [Rust `std::path::PathBuf::join` documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join) (specifically the note about absolute paths)
*   [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)