Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Multipart Filename

🚨 Severity
CRITICAL

💡 Description
In `syscore/src/server/aether.rs`, the `upload_handler` function receives file uploads via `axum::extract::Multipart`. The `filename` field from the multipart request is read directly from user input (`field.file_name().map(|s| s.to_string())`) and used to construct a file path via `PathBuf::join` (`let file_path = version_dir.join(&filename);`).

Rust's `PathBuf::join` behavior dictates that if the appended path is an absolute path (e.g., `/etc/passwd`), it completely replaces the base path. Furthermore, since the `filename` is not sanitized to strip path traversal sequences (`../`), an attacker can easily overwrite arbitrary files on the filesystem or save files outside the intended `storage/aether` directory.

Relevant code snippet in `syscore/src/server/aether.rs` around line 133:
```rust
if name == "file" {
    filename = field.file_name().map(|s| s.to_string());
    // ...
}
```

And around line 160:
```rust
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

🎯 Potential Impact
An authenticated attacker (or anyone if the weak default `AETHER_UPLOAD_KEY` is in use) can upload malicious files to arbitrary locations on the server, potentially leading to Remote Code Execution (RCE) by overwriting critical system files, configuration files, or user binaries. It also allows arbitrary file writes leading to denial of service or data corruption.

🛠️ Steps to Reproduce
1. Retrieve the valid API key (or use the default `update_me_please`).
2. Construct a multipart POST request to the `/api/v1/aether` (or the respective upload endpoint).
3. Set the `file` field with a malicious `filename` containing path traversal or an absolute path (e.g., `filename="../../../../../etc/cron.d/malicious"` or `filename="/root/.ssh/authorized_keys"`).
4. Include the required fields (`version`, etc.).
5. Send the request. The server will write the file contents to the specified location, completely bypassing the intended storage directory.

✅ Recommended Remediation
Implement strict filename sanitization before passing it to `PathBuf::join`. Consider the following steps:
1. Strip out any path separators (`/` or `\`) and directory traversal sequences (`..`).
2. Reject filenames that are absolute paths.
3. Consider generating a safe, random filename (e.g., using UUIDs) on the server side and storing the original filename only in metadata, mapped appropriately.

Example fix using the `path-clean` crate or standard library components to extract only the final file name component:
```rust
use std::path::Path;

let safe_filename = Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;

let file_path = version_dir.join(safe_filename);
```

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Rust `PathBuf::join` documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
