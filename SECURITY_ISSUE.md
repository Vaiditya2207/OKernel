Title: 🛡️ CRITICAL Arbitrary File Write: Path Traversal in Aether Upload Handler

Body:

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend service contains a critical Arbitrary File Write vulnerability in the `/api/v1/aether` upload handler (`syscore/src/server/aether.rs`). While the handler validates the `version` parameter for path traversal characters, it fails to sanitize the `filename` extracted from the multipart form data (specifically the `Content-Disposition` header). An attacker can supply a filename containing directory traversal sequences (e.g., `../../etc/passwd`) or an absolute path (e.g., `/tmp/malicious.sh`) to write arbitrary files to the filesystem with the privileges of the `syscore` process.

This vulnerability is exacerbated by the presence of a hardcoded default API key (`"update_me_please"`) in the same file, which allows unauthorized access if the `AETHER_UPLOAD_KEY` environment variable is not set.

Vulnerable Code (`syscore/src/server/aether.rs`):
```rust
// No sanitization on filename
if name == "file" {
    filename = field.file_name().map(|s| s.to_string());
    // ...
}
// ...
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await...
```

🎯 Potential Impact
*   **Remote Code Execution (RCE):** An attacker can overwrite system binaries, startup scripts, or cron jobs to execute arbitrary code.
*   **System Compromise:** Attackers can overwrite critical configuration files (e.g., `/etc/passwd`, `/etc/shadow` if running as root, or user-level configs like `~/.ssh/authorized_keys`).
*   **Denial of Service:** Critical system files can be corrupted or deleted.

🛠️ Steps to Reproduce
1.  Target a running instance of `syscore` (default port 3001).
2.  Send a POST request to `/api/v1/aether` with the header `Authorization: Bearer update_me_please` (or the configured key).
3.  Include a multipart form-data body with:
    *   `version`: `v1`
    *   `file`: A file part with `filename="../../../../../tmp/pwned.txt"` and some content.
4.  Observe that the file is written to `/tmp/pwned.txt` (or relative to the CWD if absolute path behavior differs by OS, but traversal allows escaping the storage directory).

✅ Recommended Remediation
1.  **Sanitize Filenames:** Implement strict validation on the `filename` field. Ensure it does not contain path separators (`/`, `\`) or traversal sequences (`..`). Use `Path::file_name()` to extract only the final component or generate a safe filename server-side (e.g., UUID).
    ```rust
    let safe_filename = std::path::Path::new(&filename)
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or((StatusCode::BAD_REQUEST, "Invalid filename"))?;
    ```
2.  **Remove Default Credentials:** Remove the default "update_me_please" fallback. The application should fail to start or deny all uploads if the `AETHER_UPLOAD_KEY` is not securely configured in the environment.
3.  **Principle of Least Privilege:** Ensure the `syscore` process runs with minimal filesystem permissions, restricted to its own storage directory.

🔗 References
*   [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
*   [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
