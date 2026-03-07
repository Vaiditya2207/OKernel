🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in /api/v1/aether

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` endpoint in `syscore/src/server/aether.rs` processes file uploads via a `multipart/form-data` request. When extracting the filename from the `file` field, it takes the raw value using `field.file_name().map(|s| s.to_string())` without any sanitization.

Later in the function, this unsanitized `filename` is directly appended to the version directory path using `PathBuf::join`:
```rust
let file_path = version_dir.join(&filename);
```

In Rust, `std::path::PathBuf::join` has a known behavior: if the argument appended is an absolute path (e.g., `/etc/passwd` or `C:\Windows\System32`), it entirely replaces the base path (`version_dir`). Additionally, attackers could use relative traversal sequences (e.g., `../../../../home/user/.ssh/authorized_keys`) to write files outside of the intended `storage/aether` directory.

Because the `upload_handler` saves the file bytes to `file_path`, an attacker who possesses the API key can overwrite arbitrary files on the filesystem with arbitrary contents, leading to Remote Code Execution (RCE) or full system compromise.

🎯 Potential Impact
An authenticated attacker (or unauthenticated, if they brute-force the default weak key "update_me_please" which is present in the fallback logic) can exploit this to write or overwrite any file on the host system that the Rust backend process has permissions to modify. This could easily lead to full Remote Code Execution (RCE) by overwriting critical system binaries, configuration files, SSH keys, or startup scripts.

🛠️ Steps to Reproduce
1. Authenticate to the `/api/v1/aether` POST endpoint (using the default key if `AETHER_UPLOAD_KEY` is unset).
2. Submit a `multipart/form-data` request with the required fields (`version`, `description`, `changelog`).
3. For the `file` part, set the filename parameter in the Content-Disposition header to an absolute path, for example: `filename="/tmp/pwned.txt"`.
4. Observe the result: The backend will write the uploaded file contents to `/tmp/pwned.txt` instead of placing it inside the intended version directory.

✅ Recommended Remediation
Implement strict sanitization of the user-provided filename before using it in filesystem operations. Only use the final component of the path and reject or replace any invalid characters.

In Rust, you can ensure you are only getting the file's base name by using `Path::new(&filename).file_name()` and converting it back to a string. Alternatively, generate a safe, random filename (like a UUID) on the server side and store the original filename in the metadata, mapping it securely for downloads.

Example patch:
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
