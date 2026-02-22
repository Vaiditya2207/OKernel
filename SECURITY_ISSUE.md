Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Filename in Aether Upload

Body:

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` accepts a multipart file upload. While it validates the `version` parameter to prevent path traversal, it blindly trusts the `filename` provided in the multipart data. This filename is joined with the version directory path. If an attacker provides an absolute path or a path containing traversal sequences (e.g., `../../`), the file can be written to arbitrary locations on the server filesystem with the permissions of the `syscore` process.

The vulnerable code block is:
```rust
// syscore/src/server/aether.rs:185
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await...
```

🎯 Potential Impact
An attacker can overwrite critical system files, configuration files, or inject malicious code (e.g., into web root, cron jobs, or `.ssh/authorized_keys`) leading to Remote Code Execution (RCE) or Denial of Service (DoS). The attacker requires only the API key (which defaults to `update_me_please` if not configured).

🛠️ Steps to Reproduce
1. Ensure the `syscore` server is running (default port 3001).
2. Send a multipart POST request to `/api/v1/aether` with:
   - `version`: `v1.0.0`
   - `file`: Any content, but set the filename to an absolute path like `/tmp/hacked` or a relative path like `../../../../tmp/hacked`.
   - `Authorization`: `Bearer update_me_please` (if default).
3. Observe that the file is written to `/tmp/hacked` instead of the intended storage directory.

✅ Recommended Remediation
Sanitize the `filename` in `upload_handler` to ensure it only contains a valid filename and no path separators. Use `std::path::Path::new(&filename).file_name()` to extract just the filename component before joining it to the directory path.

Example fix:
```rust
let clean_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|s| s.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;
let file_path = version_dir.join(clean_filename);
```

🔗 References
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
