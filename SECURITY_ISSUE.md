Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Multipart Filename in /api/v1/aether

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend contains a severe Arbitrary File Write vulnerability in `syscore/src/server/aether.rs` at the `/api/v1/aether` (upload) endpoint. The vulnerability occurs because the `filename` extracted from the multipart file upload is not sanitized before being appended to the base directory path using `PathBuf::join()`.

In Rust, `std::path::PathBuf::join(path)` has a known behavior where if the appended `path` is absolute (e.g., `/etc/passwd`), it replaces the entire preceding base path. Because the code at line 192 (`let file_path = version_dir.join(&filename);`) uses the raw, unsanitized `filename` from the upload request, an attacker can supply an absolute path or a path containing traversal sequences (`../`) to write arbitrary files anywhere on the file system where the server process has write permissions.

🎯 Potential Impact
An attacker with upload access can overwrite critical system files (e.g., `/etc/passwd`, `/etc/shadow`, authorized_keys), overwrite application source code or configuration files to achieve Remote Code Execution (RCE), or overwrite binaries. This leads to a full system compromise. The impact is exacerbated by the fact that the default API key is weak (`"update_me_please"`) if `AETHER_UPLOAD_KEY` is not set.

🛠️ Steps to Reproduce
1. Start the backend service.
2. Send a POST request to `/api/v1/aether` using a tool like `curl`, ensuring you provide the default or known `Authorization: Bearer update_me_please` header.
3. In the multipart form data, include a `version` field (e.g., `1.0.0`) and a `file` field.
4. Modify the `filename` attribute in the `Content-Disposition` header for the `file` part to be an absolute path such as `/tmp/pwned.txt` or `../../../../tmp/pwned.txt`.
   Example payload structure:
   ```http
   POST /api/v1/aether HTTP/1.1
   Host: localhost:3001
   Authorization: Bearer update_me_please
   Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

   ------WebKitFormBoundary
   Content-Disposition: form-data; name="version"

   1.0.0
   ------WebKitFormBoundary
   Content-Disposition: form-data; name="file"; filename="/tmp/pwned.txt"
   Content-Type: text/plain

   malicious content
   ------WebKitFormBoundary--
   ```
5. Observe that `malicious content` is written to `/tmp/pwned.txt` on the server rather than within `storage/aether/1.0.0/`.

✅ Recommended Remediation
Sanitize the `filename` before joining it with the base path. Do not trust user-provided filenames.
1. Reject any filename that contains path separators (`/`, `\`) or traversal sequences (`..`).
2. Alternatively, extract only the final file component using standard library methods. In Rust, you can use `std::path::Path::new(&filename).file_name()` to extract just the base filename, discarding any directory components.
3. Validate that the final resolved path resides within the intended storage directory before writing to it, using a canonicalization check.

🔗 References
- [Rust `PathBuf::join` documentation detailing absolute path replacement](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')](https://cwe.mitre.org/data/definitions/22.html)
