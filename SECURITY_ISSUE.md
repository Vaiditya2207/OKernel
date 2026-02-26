Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in Aether Upload

Body:

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` (lines 191-224) fails to sanitize the `filename` provided in the multipart form data. While the `version` parameter is checked for path traversal characters (lines 207-209), the `filename` extracted from the multipart field is trusted implicitly.

```rust
// syscore/src/server/aether.rs:184
filename = field.file_name().map(|s| s.to_string());

// ...

// syscore/src/server/aether.rs:219
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await...
```

An attacker can supply a filename containing directory traversal sequences (e.g., `../../../../etc/passwd` or `../../../../root/.ssh/authorized_keys`) to overwrite arbitrary files on the system with the privileges of the syscore process.

This is compounded by the use of a weak default API key ("update_me_please") if `AETHER_UPLOAD_KEY` is not set in the environment.

🎯 Potential Impact
**Remote Code Execution (RCE):** An attacker could overwrite executable files, libraries, or configuration files (like `~/.ssh/authorized_keys` if running as root/user) to gain full control over the server.
**Data Destruction:** Critical system files could be overwritten or corrupted.

🛠️ Steps to Reproduce
1. Ensure the `syscore` server is running.
2. Send a POST request to `/api/v1/aether`.
   - Headers: `Authorization: Bearer update_me_please`
3. payload: Multipart form data
   - `version`: "9.9.9"
   - `file`: (content="pwned", filename="../../pwned.txt")
4. Observe that `pwned.txt` is created in `storage/aether/` (parent of the version directory) instead of inside the version directory.

✅ Recommended Remediation
1. Sanitize the `filename` before using it. Use `std::path::Path::new(&filename).file_name()` to extract only the final component.
2. Explicitly validate that the `filename` does not contain path separators (`/` or `\`) or `..`.

```rust
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|s| s.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;
```

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
