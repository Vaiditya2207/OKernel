Title: 🛡️ CRITICAL Arbitrary File Write / Auth Bypass: Unsanitized multipart filenames and weak default API key in `/api/aether/upload`

🚨 Severity
CRITICAL

💡 Description
There are two chained vulnerabilities in the `upload_handler` function located in `syscore/src/server/aether.rs`:

1. **Weak Default API Key (Broken Auth):** At line 314, `AETHER_UPLOAD_KEY` defaults to `"update_me_please"` if the environment variable is not set. This allows an attacker to easily guess the authorization token and bypass authentication completely.
2. **Arbitrary File Write (Path Injection):** Starting at line 341, the filenames provided in the multipart request (`filename`, `bundle_filename`, `patch_filename`) are extracted directly using `field.file_name()`. These unsanitized strings are later used with `PathBuf::join()` (e.g., at line 400). In Rust, if the string passed to `PathBuf::join()` is an absolute path (e.g., `/root/.ssh/authorized_keys`), it completely replaces the base path. This allows an attacker to write uploaded contents to any location on the file system with the permissions of the application process.

🎯 Potential Impact
An unauthenticated attacker can upload arbitrary files to any location on the server. By overwriting sensitive files such as `/etc/shadow`, `/root/.ssh/authorized_keys`, or replacing application binaries, the attacker could easily achieve complete Remote Code Execution (RCE) and system takeover.

🛠️ Steps to Reproduce
1. Ensure the `AETHER_UPLOAD_KEY` environment variable is not set (or use the known `"update_me_please"` fallback).
2. Send an HTTP POST request to the upload endpoint with the `Authorization: Bearer update_me_please` header.
3. In the multipart form data, include a field named `file`, set its filename to an absolute path (e.g., `filename="/tmp/pwned.txt"`), and provide some arbitrary data as the file content.
4. Also include the required `version` parameter in the multipart data (e.g., `version="1.0.0"`).
5. Observe that the file is successfully created at `/tmp/pwned.txt` instead of within the intended `STORAGE_DIR/1.0.0` directory.

✅ Recommended Remediation
1. **Remove Weak Defaults:** Remove the `.unwrap_or_else(|_| "update_me_please".to_string())` logic. If `AETHER_UPLOAD_KEY` is not present in the environment, the server should fail to start, or the endpoint should strictly deny all requests.
2. **Sanitize Filenames:** Do not trust user-provided filenames. Either generate unique server-side names (e.g., using UUIDs) or extract only the final path component and sanitize it strictly (e.g., stripping out all path separators `\`, `/`, and `..` sequences) before using it in `PathBuf::join()`. Consider using crates like `sanitize-filename` to ensure safe file names.

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Rust PathBuf::join Documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)
