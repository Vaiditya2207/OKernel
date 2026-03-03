Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in /api/v1/aether

Body:

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` contains a critical Path Traversal vulnerability. When processing a multipart form upload for the Aether application, the `filename` field from the uploaded file part is read directly and used to construct a file path without any sanitization.

```rust
// syscore/src/server/aether.rs:136
if name == "file" {
    filename = field.file_name().map(|s| s.to_string()); // Unsanitized input
    let data = field.bytes().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    file_bytes = Some(data.to_vec());
}
```

Later, this `filename` is directly appended to the base storage directory using `PathBuf::join`:

```rust
// syscore/src/server/aether.rs:168
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

In Rust, `std::path::PathBuf::join` has a known behavior: if the argument appended is an absolute path (e.g., `/etc/passwd`), it completely replaces the current path. Furthermore, directory traversal characters like `../` are not stripped, allowing an attacker to write files anywhere on the file system, constrained only by the application's runtime permissions.

🎯 Potential Impact
An authenticated attacker (or anyone who has access to the default API key "update_me_please") can upload an arbitrary file to any location on the server. This can lead to Remote Code Execution (RCE) by overwriting system binaries, configuration files, SSH authorized keys, or manipulating cron jobs. The impact is a complete compromise of the underlying container or host system.

🛠️ Steps to Reproduce
1. Acquire the API Key (defaulting to "update_me_please" if not configured).
2. Construct a multipart POST request to `/api/v1/aether`.
3. Set the `version` field to a valid new version (e.g., "1.0.1").
4. Set the `file` field with a malicious filename.
   - Example 1 (Absolute overwrite): `filename="/tmp/hacked.txt"`
   - Example 2 (Relative traversal): `filename="../../../../tmp/hacked.txt"`
5. Send the request:
```bash
curl -X POST http://localhost:3001/api/v1/aether \
  -H "Authorization: Bearer update_me_please" \
  -F "version=1.0.1" \
  -F "description=malicious" \
  -F "changelog=malicious" \
  -F "file=@local_payload.bin;filename=/tmp/hacked.txt"
```
6. Observe that `local_payload.bin` has been written to `/tmp/hacked.txt` instead of the intended `storage/aether/1.0.1/` directory.

✅ Recommended Remediation
Implement strict filename sanitization before passing it to `PathBuf::join`. A secure approach is to extract only the final file component and strip out any path separators.

```rust
use std::path::Path;

// ...
let safe_filename = Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;

let file_path = version_dir.join(safe_filename);
```
Additionally, consider generating a random, safe identifier (e.g., a UUID) for the stored file on disk and mapping the original filename via the `metadata.json` database, entirely separating user-supplied input from filesystem operations.

🔗 References
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
- Rust `PathBuf::join` documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
