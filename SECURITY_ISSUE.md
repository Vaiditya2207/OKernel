Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in /api/v1/aether

Body:

🚨 Severity
CRITICAL

💡 Description
The `syscore/src/server/aether.rs` file contains a critical Path Traversal vulnerability in the `upload_handler` function. The handler accepts a multipart file upload and extracts the filename using `field.file_name()`. This filename is then directly joined to the storage directory path using `version_dir.join(&filename)` without any sanitization. An attacker can craft a filename containing `../` sequences to traverse out of the intended directory and overwrite any file on the system that the server process has write access to.

Relevant code snippet (`syscore/src/server/aether.rs`):
```rust
        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
            // ...
        }
    // ...
    let filename = filename.ok_or((StatusCode::BAD_REQUEST, "Missing filename".to_string()))?;
    // ...
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

Additionally, the API endpoint is protected by a weak authentication mechanism that falls back to a default hardcoded key `"update_me_please"` if the `AETHER_UPLOAD_KEY` environment variable is not set.

🎯 Potential Impact
An attacker can achieve Remote Code Execution (RCE) by overwriting critical system files, binaries, or scripts (e.g., `~/.ssh/authorized_keys`, web server configuration, or the application binary itself). They can also deface the application or cause Denial of Service by corrupting data.

🛠️ Steps to Reproduce
1.  Target a running instance of `syscore` (default port 3001).
2.  Send a POST request to `/api/v1/aether` with the header `Authorization: Bearer update_me_please` (or the configured key).
3.  Include a multipart form with a `file` field.
4.  Set the filename of the file to `../../../../../tmp/pwned`.
5.  Observe that the file is written to `/tmp/pwned` on the server filesystem.

✅ Recommended Remediation
1.  **Sanitize Filenames**: Ensure that the filename only contains the base name component. In Rust, you can use `Path::new(&filename).file_name()` to strip directory components.
    ```rust
    let safe_filename = std::path::Path::new(&filename)
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or((StatusCode::BAD_REQUEST, "Invalid filename"))?;
    ```
2.  **Remove Hardcoded Secrets**: Remove the default fallback for `AETHER_UPLOAD_KEY` and fail to start if the secret is not configured.
3.  **Validate Paths**: Verify that the resolved `file_path` is still within the `storage/aether` directory using `canonicalize()` (with care for symlink attacks, though less relevant here if filename is basename only).

🔗 References
*   [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
*   [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
