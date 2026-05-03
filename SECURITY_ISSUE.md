Title: 🛡️ [CRITICAL] Arbitrary File Write & Broken Auth: Unsanitized Filename and Weak Default Key in Aether Upload Handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` contains two critical vulnerabilities:
1. **Broken Auth (Hardcoded Fallback Key):** On line 315, the API expects an authorization key from `AETHER_UPLOAD_KEY`, but falls back to a weak default string (`"update_me_please"`) via `unwrap_or_else` if the environment variable is not set.
2. **Arbitrary File Write (Path Traversal):** The handler blindly extracts filenames from the multipart request (`field.file_name()`) on lines 340, 344, and 348. These unsanitized filenames are later directly used in `PathBuf::join` (lines 387, 392, 398). In Rust, `PathBuf::join` replaces the entire base path if the appended string is an absolute path. This allows an attacker to write arbitrary files anywhere on the file system by supplying an absolute path (e.g., `/etc/passwd`) as the filename.

🎯 Potential Impact
An unauthenticated attacker could guess or know the default fallback key (`update_me_please`) to gain unauthorized access to the upload endpoint. From there, the attacker could exploit the path traversal vulnerability to overwrite critical system files, potentially leading to Remote Code Execution (RCE), privilege escalation, or complete system compromise.

🛠️ Steps to Reproduce
1. Ensure the `AETHER_UPLOAD_KEY` environment variable is not set on the server.
2. Send a POST request to the `/upload` endpoint (or equivalent route for `upload_handler`).
3. Include the `Authorization: Bearer update_me_please` header.
4. Provide a multipart form payload with a file field where the filename is set to an absolute path, e.g., `filename="/tmp/pwned.txt"`.
5. Observe that the file is written to `/tmp/pwned.txt` instead of the intended version directory.

✅ Recommended Remediation
1. **Remove Weak Fallback:** Do not use a fallback default key for authentication. If `AETHER_UPLOAD_KEY` is not present, the application should fail securely (e.g., return a 500 error or panic at startup rather than allowing weak access).
2. **Sanitize Filenames:** Sanitize all user-provided filenames before concatenating them with a base directory. Use `std::path::Path::new(&filename).file_name()` to extract only the final file component, stripping any directory traversal elements or absolute path markers.

🔗 References
- OWASP Top 10: Broken Access Control (Broken Auth)
- OWASP Top 10: Injection (Path Traversal / Arbitrary File Write)
- Rust Documentation: `PathBuf::join` behavior with absolute paths: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
