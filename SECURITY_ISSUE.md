Title: 🛡️ [CRITICAL] Injection: Arbitrary File Write via Unsanitized Multipart Filename

🚨 Severity
CRITICAL

💡 Description
The Aether version upload handler located in `syscore/src/server/aether.rs` contains an Arbitrary File Write vulnerability due to the unsanitized use of `filename` from a multipart form data request.

Specifically, on line 192 of `syscore/src/server/aether.rs` (`let file_path = version_dir.join(&filename);`), the `filename` variable extracted directly from the multipart request is joined to the target directory using `PathBuf::join`. Rust's `PathBuf::join` replaces the entire path if the appended component is an absolute path. Consequently, if an attacker uploads a file with an absolute path as the filename (e.g., `/etc/passwd`), the resulting `file_path` will be exactly `/etc/passwd`, allowing the attacker to overwrite any file on the system that the Axum process has permissions for. Furthermore, path traversal attacks (e.g., `../../../../root/.ssh/authorized_keys`) are also possible if relative paths are allowed without being cleaned.

🎯 Potential Impact
An attacker with upload permissions (which may be easily bypassed if the weak default `AETHER_UPLOAD_KEY` is still in use) can completely overwrite arbitrary files on the system hosting the Axum server. This can lead to Remote Code Execution (RCE), privilege escalation, denial of service by overwriting critical system binaries, or data corruption.

🛠️ Steps to Reproduce
1.  Identify the `/api/v1/aether` (or the corresponding upload endpoint) endpoint for the Aether server.
2.  Send a `multipart/form-data` POST request to the upload endpoint with valid authentication credentials (or utilizing the default `"update_me_please"` fallback key if applicable).
3.  Include a `file` field with a payload and a manipulated filename using an absolute path (e.g., `/tmp/hacked.txt`).
4.  Observe that the file is written to `/tmp/hacked.txt` on the server instead of being placed under the `STORAGE_DIR/version/` path.

Example `curl` payload:
```bash
curl -X POST http://<SERVER_URL>:<PORT>/api/v1/aether \
  -H "Authorization: Bearer update_me_please" \
  -F "version=1.0.0-hack" \
  -F "file=@local_payload.txt;filename=/tmp/hacked.txt"
```

✅ Recommended Remediation
Implement filename sanitization before passing it to `PathBuf::join`. Do not rely on user-provided filenames directly.
*   **Sanitize Input:** Use a library like `sanitize-filename` (if available in Rust ecosystem, or manually filter out dangerous characters and path separators `/` and `\`).
*   **Use Safe Path Builders:** Extract only the file name component, discarding any directory paths provided in the `filename` string. For example, using `std::path::Path::new(&filename).file_name().unwrap().to_string_lossy().to_string()` can help extract just the final filename portion safely.
*   **Generate Random Filenames:** Alternatively, ignore the user-provided filename entirely, generate a secure random filename (e.g., a UUID), and store the original filename in metadata only.

🔗 References
*   [OWASP: Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
*   [Rust Documentation: `PathBuf::join`](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
