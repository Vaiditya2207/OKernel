Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in Aether Uploads

🚨 Severity
CRITICAL

💡 Description
An Arbitrary File Write vulnerability exists in the Aether upload endpoint (`/api/v1/aether`). In `syscore/src/server/aether.rs`, the `upload_handler` function extracts the filename from the multipart form data using `field.file_name()` and subsequently uses it to construct a file path via `version_dir.join(&filename)`. The filename is not sanitized. Because `PathBuf::join` replaces the base path entirely if the appended path is absolute (e.g., `/etc/passwd`), or allows directory traversal (e.g., `../../../../etc/passwd`), an authenticated attacker can write arbitrary files to anywhere on the host filesystem with the privileges of the Rust backend process.

Vulnerable code snippet in `syscore/src/server/aether.rs` around line 192:
```rust
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

🎯 Potential Impact
An attacker with the `AETHER_UPLOAD_KEY` could overwrite critical system files (like `/etc/passwd`, `~/.ssh/authorized_keys`, or application configuration files), leading to a complete system compromise, Remote Code Execution (RCE), or denial of service by overwriting essential executables.

🛠️ Steps to Reproduce (If applicable)
1. Obtain the `AETHER_UPLOAD_KEY` (or rely on the default `update_me_please`).
2. Construct a multipart POST request to the Aether upload endpoint (`/api/v1/aether`).
3. Set the `version` field to a valid string (e.g., `v1.0.0`).
4. Set the `file` field name to an absolute path or path traversal string, e.g., `filename="/tmp/pwned.txt"` or `filename="../../../../../tmp/pwned.txt"`.
5. Provide arbitrary content for the file.
6. Observe that the file is written to the specified location on the server instead of the intended `storage/aether/v1.0.0/` directory.

✅ Recommended Remediation
Sanitize the `filename` before using it in `PathBuf::join`. Extract only the final file component, ignoring any directory paths.

Example fix:
```rust
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;

let file_path = version_dir.join(safe_filename);
```

🔗 References
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
- Rust `PathBuf::join` documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
