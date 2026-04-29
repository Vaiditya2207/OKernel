Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Filename in upload_handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` contains a critical Arbitrary File Write vulnerability. Filenames extracted from multipart form data (`field.file_name()`) are completely unsanitized and are passed directly into `PathBuf::join` when constructing the final file path for saving uploaded files (`let file_path = version_dir.join(&filename);`).

In Rust, the `PathBuf::join` behavior is such that if the appended string represents an absolute path, it entirely replaces the base path. This allows an attacker to bypass the intended `STORAGE_DIR` and write files anywhere on the system that the application process has write access to. Furthermore, relative path traversal sequences (e.g., `../../../`) are not mitigated.

🎯 Potential Impact
An attacker with upload privileges can write arbitrary files to any location on the file system accessible by the Axum application process. This can lead to Remote Code Execution (RCE) by overwriting executable code, configuration files, or SSH keys, potentially fully compromising the backend server.

🛠️ Steps to Reproduce
1. Start the Axum server locally (`cargo run` from `syscore`).
2. Construct a multipart POST request to the upload endpoint using the required API key in the `Authorization` header.
3. In the form data, include a file part, but intercept the request to change the `filename` attribute to an absolute path, for example: `filename="/tmp/pwned.txt"`.
4. Provide valid `version` and `channel` text fields.
5. Send the request.
6. Observe that `pwned.txt` is created in `/tmp/` instead of the expected version subdirectory within `storage/aether`.

✅ Recommended Remediation
Implement strict input sanitization on all user-supplied filenames before passing them to filesystem APIs. Use `std::path::Path::new(&filename).file_name()` to safely extract only the filename component, stripping any absolute paths or relative traversal characters.

Example fix in `upload_handler`:
```rust
// Sanitize the filename extracted from the multipart field
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename format".to_string()))?;

// Safely join the sanitized filename
let file_path = version_dir.join(safe_filename);
```

🔗 References
- [Rust std::path::PathBuf::join Documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
- [OWASP Unrestricted File Upload Vulnerability](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
