Title: 🛡️ CRITICAL Injection: Unsanitized input in /api/v1/aether upload_handler

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend service exposes a file upload endpoint for the Aether terminal via the `upload_handler` function in `syscore/src/server/aether.rs`. The application retrieves the `filename` from the incoming multipart form data (line 157). However, the `filename` is not sanitized before being appended to the `version_dir` path using `PathBuf::join` (line 182): `let file_path = version_dir.join(&filename);`.
In Rust, if `PathBuf::join` is provided with an absolute path, it replaces the base path entirely. Furthermore, the filename can contain `../` sequences, allowing for path traversal. This allows an attacker to write arbitrary files anywhere on the filesystem with the permissions of the `syscore` process.

🎯 Potential Impact
An attacker with access to the Aether upload API can exploit this vulnerability to achieve Remote Code Execution (RCE) by overwriting critical system files, such as `~/.ssh/authorized_keys`, cron jobs, or the application executable itself. It could also lead to Denial of Service (DoS) by overwriting configuration files. The impact is complete system compromise of the `syscore` backend server.

🛠️ Steps to Reproduce (If applicable)
1. Prepare a malicious multipart/form-data request to the Aether upload API endpoint (`POST /api/v1/aether`).
2. Include the required `version` and authorization headers.
3. Include a `file` field where the `filename` parameter is crafted as an absolute path (e.g., `filename="/etc/cron.d/malicious_cron"`) or uses directory traversal (e.g., `filename="../../../../etc/passwd"`).
4. Send the request. Observe that the file is written to the specified arbitrary location on the server instead of the intended `storage/aether/<version>` directory.

✅ Recommended Remediation
Implement strict validation and sanitization of the user-provided `filename` before constructing the file path. You should extract only the final file name component and reject any path traversal characters.

Example using `std::path::Path`:
```rust
let filename = field.file_name().unwrap_or("default.bin");
let sanitized_filename = std::path::Path::new(filename)
    .file_name()
    .and_then(|name| name.to_str())
    .unwrap_or("default.bin");

let file_path = version_dir.join(sanitized_filename);
```
Additionally, consider validating the file extension and MIME type if applicable.

🔗 References
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
- Rust `std::path::PathBuf::join` Documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
