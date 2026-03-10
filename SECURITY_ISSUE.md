Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Multipart Filename

🚨 Severity
CRITICAL

💡 Description
An Arbitrary File Write vulnerability exists in the `/api/v1/aether` upload endpoint (`syscore/src/server/aether.rs`, line 155). The `upload_handler` function receives a `multipart` form containing a file upload. It extracts the `filename` from the form data (line 155: `filename = field.file_name().map(|s| s.to_string());`) and later joins it with the base storage directory (`version_dir.join(&filename)` on line 186) without any sanitization or validation of the filename itself.

While the `version` parameter is checked for directory traversal sequences like `..`, `/`, and `\` (line 176), the `filename` parameter from the multipart field is completely unchecked.

In Rust, `std::path::PathBuf::join` has a known behavior where if the path to be appended is absolute, it completely replaces the current path. Thus, if an attacker uploads a file with an absolute path (e.g., `/etc/passwd` or `/root/.ssh/authorized_keys`), the `file_path` will resolve to that absolute path, and `tokio_fs::write(&file_path, &file_bytes)` will overwrite that file on the server. Furthermore, standard path traversal like `../../../etc/passwd` would also write outside of the intended directory if `PathBuf::join` combines it with the base directory.

🎯 Potential Impact
An attacker with upload access (even with the default `update_me_please` key if `AETHER_UPLOAD_KEY` is not set) can write arbitrary files to the server's filesystem, leading to remote code execution (RCE) by overwriting critical system files (e.g., cron jobs, authorized_keys), defacement, or denial of service by overwriting vital configuration files.

🛠️ Steps to Reproduce (If applicable)
1. Prepare a malicious file payload (e.g., a simple text file with malicious content).
2. Construct a multipart POST request to the `/api/v1/aether` endpoint.
3. Include the required Authorization header (default: `Bearer update_me_please`).
4. Include the required text fields `version`, `description`, and `changelog`. Ensure the `version` string is valid (e.g., "1.0.0").
5. Include the file field, but manually set the `filename` parameter in the `Content-Disposition` header to an absolute path, for example: `filename="/tmp/pwned.txt"`.
6. Send the request. Observe that the file is written to `/tmp/pwned.txt` instead of the expected storage directory (`storage/aether/1.0.0/pwned.txt`).

✅ Recommended Remediation
Sanitize the `filename` parameter before using it with `PathBuf::join`. The easiest and safest way in Rust is to extract only the final file name component and ensure it doesn't contain path separators.

```rust
// In syscore/src/server/aether.rs:
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .unwrap_or("default_filename");

let file_path = version_dir.join(safe_filename);
```
Additionally, consider implementing a strict allowlist of permitted characters for filenames to further reduce risk.

🔗 References
* [Rust std::path::PathBuf::join documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
* [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
