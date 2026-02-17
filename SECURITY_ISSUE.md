Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in Aether Upload API

Body:

🚨 Severity
CRITICAL

💡 Description
A critical path traversal vulnerability exists in the `upload_handler` function within `syscore/src/server/aether.rs`.
The vulnerability allows an authenticated attacker (or anyone with the default API key) to write arbitrary files to the server's filesystem by manipulating the `filename` field in a multipart/form-data request.
Specifically, the code at lines 156-157 extracts the filename from the multipart field without any sanitization:
```rust
        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
```
And then joins it directly to the version directory path at lines 191-192:
```rust
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes)...
```
If `filename` contains directory traversal sequences like `../../`, `PathBuf::join` will resolve to a path outside the intended directory. When `tokio_fs::write` is called, it writes the attacker-controlled content to the arbitrary location.

This issue is compounded by the use of a hardcoded default API key (`update_me_please`) in `syscore/src/server/aether.rs` line 140:
```rust
    let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

🎯 Potential Impact
1. **Remote Code Execution (RCE):** An attacker can overwrite system binaries (e.g., `syscore` itself if permissions allow, or scripts/executables in the path) or configuration files (e.g., `authorized_keys`) to gain full control over the server.
2. **System Compromise:** Attackers can overwrite critical system files (e.g., `/etc/passwd` or `/etc/shadow`) leading to denial of service or privilege escalation.
3. **Data Integrity Loss:** Any file writable by the server process can be corrupted or replaced.

🛠️ Steps to Reproduce
1. Ensure the `syscore` server is running (default port 3001).
2. Authenticate using the `Authorization: Bearer update_me_please` header (unless `AETHER_UPLOAD_KEY` is set).
3. Send a POST request to `/api/v1/aether` with `multipart/form-data`.
4. Include a `version` field with a valid version string (e.g., `v1.0.0`).
5. Include a `file` field with a malicious filename, e.g., `../../../../tmp/pwned.txt`, and arbitrary content.
6. Verify that `/tmp/pwned.txt` has been created with the provided content.

Example curl command:
```bash
curl -X POST http://localhost:3001/api/v1/aether \
  -H "Authorization: Bearer update_me_please" \
  -F "version=v1.0.0" \
  -F "description=Test" \
  -F "file=@malicious.txt;filename=../../../../tmp/pwned.txt"
```

✅ Recommended Remediation
1. **Sanitize Filenames:** Implement strict validation on the `filename` provided in the upload. Ensure it contains only allowed characters (alphanumeric, dots, dashes, underscores) and does not contain path separators (`/`, `\`) or traversal sequences (`..`).
   Example:
   ```rust
   let safe_filename = Path::new(&filename).file_name().unwrap().to_string_lossy();
   if safe_filename != filename {
       return Err((StatusCode::BAD_REQUEST, "Invalid filename".to_string()));
   }
   ```
2. **Remove Default Secret:** Remove the hardcoded fallback `"update_me_please"` and require `AETHER_UPLOAD_KEY` to be set in the environment. If it is not set, the server should fail to start or disable the upload endpoint.
3. **Principle of Least Privilege:** Ensure the server process runs with minimal filesystem permissions, restricting where it can write.

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
