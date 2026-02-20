Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in Aether Upload

Body:

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend service contains a critical Arbitrary File Write vulnerability in the `/api/v1/aether` upload endpoint (`syscore/src/server/aether.rs`).

While the `version` parameter is sanitized to prevent path traversal, the `filename` extracted from the multipart form data is used directly in `PathBuf::join` without validation.

```rust
// syscore/src/server/aether.rs:153
let filename = filename.ok_or((StatusCode::BAD_REQUEST, "Missing filename".to_string()))?;
// ...
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await...
```

An attacker can supply a filename containing `../` sequences (e.g., `../../../../etc/passwd`) to traverse out of the intended storage directory and overwrite any file writable by the `syscore` process.

Additionally, the endpoint is protected by a weak default API key (`update_me_please`) if the `AETHER_UPLOAD_KEY` environment variable is not set.

🎯 Potential Impact
*   **Remote Code Execution (RCE):** An attacker can overwrite executable files, scripts, or configuration files (e.g., `.bashrc`, `ssh_keys`) to gain persistent access or execute arbitrary code.
*   **System Compromise:** Overwriting critical system files could lead to denial of service or full system takeover.
*   **Data Integrity Loss:** An attacker can delete or corrupt legitimate files.

🛠️ Steps to Reproduce
1.  Start the `syscore` server (`cargo run`).
2.  Send a POST request to `http://localhost:3001/api/v1/aether` with the header `Authorization: Bearer update_me_please`.
3.  Include a multipart file part with `filename="../../pwned.txt"`.
4.  Observe that `pwned.txt` is created outside the `storage/aether` directory.

✅ Recommended Remediation
1.  **Sanitize Filename:** Validate the `filename` to ensure it does not contain path traversal characters (`..`, `/`, `\`). Use `Path::file_name()` to extract only the final component.
    ```rust
    let safe_filename = Path::new(&filename).file_name().unwrap_or_default();
    ```
2.  **Enforce Strong Authentication:** Remove the default API key fallback. Require `AETHER_UPLOAD_KEY` to be set and fail securely if missing.
3.  **Principle of Least Privilege:** Ensure the `syscore` process runs with minimal filesystem permissions.

🔗 References
*   [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
*   [CWE-22: Improper Limitation of a Pathname to a Restricted Directory](https://cwe.mitre.org/data/definitions/22.html)
