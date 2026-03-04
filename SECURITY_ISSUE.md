Title: 🛡️ CRITICAL Arbitrary File Write: Unsanitized filename in /upload endpoint (syscore)

Body:

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` accepts a multipart file upload. The filename is extracted directly from the `Content-Disposition` header without any sanitization or validation. This filename is then joined with the storage directory path using `PathBuf::join`. Since `PathBuf::join` does not resolve path traversal sequences (`../`) when joining, an attacker can provide a filename like `../../../../etc/passwd` to write files outside the intended directory.

This vulnerability is exacerbated by the use of a hardcoded default API key ("update_me_please") if the `AETHER_UPLOAD_KEY` environment variable is not set.

File: `syscore/src/server/aether.rs`

Lines:
```rust
        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
            // ...
        }
```
and
```rust
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await...
```

🎯 Potential Impact
An attacker can overwrite critical system files (e.g., binaries, configuration files, SSH keys) leading to Remote Code Execution (RCE) or Denial of Service (DoS). The attacker could also write a malicious web shell or a cron job to gain persistent access to the server.

🛠️ Steps to Reproduce
1.  Target a running instance of `syscore`.
2.  Send a POST request to `/upload` with the header `Authorization: Bearer update_me_please`.
3.  Include a multipart form data with a `file` field.
4.  Set the `filename` parameter of the `file` field to `../../../tmp/pwned.txt`.
5.  Set the `version` field to `v1.0.0`.
6.  The file `pwned.txt` will be created in `/tmp/` on the server filesystem (assuming the process has write permissions).

✅ Recommended Remediation
1.  **Sanitize the filename:** Use `Path::file_name()` to extract only the filename component, stripping any directory path. Alternatively, generate a random filename (e.g., using UUIDs) and store the original filename in the metadata.
2.  **Validate the path:** Ensure the resolved path is within the expected storage directory using `fs::canonicalize` or similar checks.
3.  **Disable default credentials:** Remove the fallback to "update_me_please" and fail securely if the API key is not configured.

🔗 References
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
- [CWE-434: Unrestricted Upload of File with Dangerous Type](https://cwe.mitre.org/data/definitions/434.html)
- [CWE-798: Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
