# 🛡️ CRITICAL Injection: Arbitrary File Write via Path Traversal in `/api/v1/aether`

## 🚨 Severity
CRITICAL

## 💡 Description
A critical Arbitrary File Write vulnerability exists in the `upload_handler` function within `syscore/src/server/aether.rs`. The application allows users to upload files via a multipart/form-data POST request to `/api/v1/aether`. While the `version` parameter is sanitized to prevent path traversal, the `filename` parameter (derived from the uploaded file's name) is used directly in a `PathBuf::join` operation without any sanitization.

In `syscore/src/server/aether.rs`:
```rust
    // ...
    if name == "file" {
        filename = field.file_name().map(|s| s.to_string());
        // ...
    }
    // ...
    // No sanitization of filename here
    // ...
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await...
```

This allows an attacker to craft a request with a filename containing directory traversal sequences (e.g., `../../../../etc/passwd`), which the application will use to construct the final file path. Since the application likely runs with significant privileges (to manage Docker containers), this can lead to overwriting critical system files.

Additionally, the endpoint is protected by a weak default API key (`update_me_please`) if the `AETHER_UPLOAD_KEY` environment variable is not set, making exploitation trivial in default configurations.

## 🎯 Potential Impact
- **Remote Code Execution (RCE):** An attacker can overwrite executable files, scripts (e.g., `.bashrc`), or the application binary itself to execute arbitrary code.
- **System Compromise:** Overwriting system configuration files (e.g., `/etc/passwd`, `/etc/shadow` if running as root, though less likely in containerized envs but possible) or application configuration.
- **Data Integrity Loss:** An attacker can overwrite or corrupt any file the application has write access to, including database files or other user data.

## 🛠️ Steps to Reproduce
1. Ensure the `syscore` server is running (default port 3001).
2. Use a tool like `curl` or a custom script to send a POST request to `/api/v1/aether`.
3. Set the `Authorization` header to `Bearer update_me_please` (or the configured key).
4. Construct a multipart/form-data body with:
   - field `version`: "1.0.0"
   - field `file`: verify specific filename payload, e.g., `filename="../../../tmp/pwned"` and content "pwned".
5. Send the request.
6. Verify that the file `/tmp/pwned` (or relative to the CWD) has been created with the content "pwned".

## ✅ Recommended Remediation
1. **Sanitize Filenames:** strictly validate or sanitize the `filename` parameter. Use `std::path::Path::file_name()` to extract only the final component, or reject filenames containing path separators (`/`, `\`).
   ```rust
   let safe_filename = std::path::Path::new(&filename)
       .file_name()
       .and_then(|s| s.to_str())
       .ok_or((StatusCode::BAD_REQUEST, "Invalid filename"))?;
   ```
2. **Remove Default Secrets:** Remove the fallback default API key ("update_me_please"). The application should fail to start if the `AETHER_UPLOAD_KEY` environment variable is not set, forcing the administrator to configure a secure key.
3. **Least Privilege:** Ensure the application runs with the minimum necessary permissions to reduce the impact of file write vulnerabilities.

## 🔗 References
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
