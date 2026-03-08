Title: 🛡️ [CRITICAL] [Injection]: Arbitrary File Write via Unsanitized Multipart Filename

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` endpoint in `syscore/src/server/aether.rs` contains an arbitrary file write vulnerability due to unsanitized multipart form filenames. At line 159, the `filename` is extracted directly from the uploaded multipart field (`filename = field.file_name().map(|s| s.to_string());`). Later, at line 192, this unsanitized `filename` is directly appended to the base directory path using Rust's `PathBuf::join`: `let file_path = version_dir.join(&filename);`.

In Rust, `PathBuf::join` replaces the base path entirely if the appended string represents an absolute path (e.g., `/etc/passwd`). Because the application executes with the privileges of its running user, an attacker can upload a file with an absolute path as the filename, bypassing the intended `STORAGE_DIR` restrictions entirely and overwriting arbitrary system files.

🎯 Potential Impact
An attacker with upload privileges (or via exploiting the fallback weak default API key) can overwrite any file on the system that the backend process has write access to. This could lead to a complete system compromise, such as overwriting SSH authorized keys, configuration files, or injecting malicious executable code.

🛠️ Steps to Reproduce
1. Use a tool like `curl` or Postman to send a POST request to the `/api/v1/aether` upload endpoint.
2. Ensure you have the required API key (or the default key `update_me_please`).
3. Construct a multipart/form-data payload.
4. Set the `filename` attribute of the `file` field to an absolute path, for example: `filename="/tmp/hacked.txt"`.
5. Set the other required fields (`version`, etc.).
6. Send the request. Observe that the file is written to `/tmp/hacked.txt` instead of the expected storage directory.

✅ Recommended Remediation
Implement strict path sanitization for uploaded filenames. The safest approach is to extract only the final component (the base name) of the provided path, discarding any directory traversal or absolute path information.

```rust
// In syscore/src/server/aether.rs

use std::path::Path;

// Before line 192:
let safe_filename = Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .unwrap_or("default_upload_name");

let file_path = version_dir.join(safe_filename);
```

Alternatively, you could generate a random UUID for the stored file on disk and map it to the original user-provided filename within the metadata JSON.

🔗 References
- Rust Documentation for PathBuf::join: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
