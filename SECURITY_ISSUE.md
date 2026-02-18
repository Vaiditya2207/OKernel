Title: 🛡️ CRITICAL Path Traversal: Arbitrary File Write via `filename` in `syscore/src/server/aether.rs`

Body:

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend service contains a critical Arbitrary File Write vulnerability in its Aether version upload handler. Specifically, the `upload_handler` function in `syscore/src/server/aether.rs` (lines 131-209) accepts a file upload via a multipart/form-data request. It extracts the `filename` from the request and uses it directly to construct the destination path for the file write without any sanitization.

In `syscore/src/server/aether.rs`:
```rust
    // Extract filename from multipart field
    if name == "file" {
        filename = field.file_name().map(|s| s.to_string());
        // ...
    }

    // ...

    // Use filename directly in path join
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await...
```

The `PathBuf::join` method in Rust behaves in a specific way:
1. If the joined path is absolute (e.g., `/etc/passwd`), it replaces the base path entirely.
2. If the joined path contains traversal characters (e.g., `../../`), it resolves relative to the base path (handled by the OS upon `write`).

This allows an authenticated attacker (or unauthenticated if the default API key is used) to write files to any location on the server's filesystem where the process has write permissions.

Additionally, the `download_handler` subsequently serves files based on the `filename` stored in the uploaded metadata, allowing for Arbitrary File Read if the attacker first uploads a malicious metadata file pointing to a sensitive system file (e.g., `/etc/shadow`).

The vulnerability is further exacerbated by the use of a hardcoded default API key (`"update_me_please"`) if the `AETHER_UPLOAD_KEY` environment variable is not set.

🎯 Potential Impact
1.  **Remote Code Execution (RCE):** An attacker can write a malicious script to a location executed by the system (e.g., `cron` directories, web roots, or `~/.ssh/authorized_keys`).
2.  **System Compromise:** Overwriting critical system configuration files (e.g., `/etc/passwd`, `/etc/hosts`) can lead to full system takeover.
3.  **Data Exfiltration:** By exploiting the linked Arbitrary File Read vulnerability, an attacker can read sensitive files from the server.
4.  **Denial of Service:** Overwriting essential system binaries or filling up the disk.

🛠️ Steps to Reproduce
1.  Target a running instance of `syscore` (default port 3001).
2.  Construct a `multipart/form-data` POST request to `/api/v1/aether`.
3.  Set the `Authorization` header to `Bearer update_me_please` (default key).
4.  Include a `version` field (e.g., `1.0.0`).
5.  Include a `file` field with a malicious filename, such as `../../../../tmp/pwned` or an absolute path like `/tmp/pwned_abs`.
6.  Send the request.
7.  Verify that the file is created at the target location, outside the intended storage directory.

(See attached `poc.py` for a script that generates this payload).

✅ Recommended Remediation
1.  **Sanitize Filenames:** Ensure that the `filename` used for storage is strictly a filename and does not contain any path separators. Use `std::path::Path::new(&filename).file_name()` to extract just the file name component.
    ```rust
    let safe_filename = std::path::Path::new(&filename)
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or((StatusCode::BAD_REQUEST, "Invalid filename"))?;
    ```
2.  **Remove Hardcoded Secrets:** Remove the default `"update_me_please"` fallback for `AETHER_UPLOAD_KEY`. The server should fail to start or refuse uploads if the key is not securely configured in the environment.
3.  **Validate Content Types:** Restrict allowed file types if possible.

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
