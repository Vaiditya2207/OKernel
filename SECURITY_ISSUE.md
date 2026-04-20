Title: 🛡️ CRITICAL Arbitrary File Write: Unsanitized input in /api/aether/upload

🚨 Severity
CRITICAL

💡 Description
The upload handler located in `syscore/src/server/aether.rs` at line 340 (and others for `bundle` and `patch`) extracts filenames directly from multipart fields (`field.file_name()`) and later uses them in a `PathBuf::join()` operation (e.g., line 387: `let file_path = version_dir.join(&filename);`).

In Rust, `PathBuf::join(path)` has a specific behavior: if the provided `path` is absolute, it completely replaces the existing base path. Since the multipart filename is entirely user-controlled and not sanitized, an attacker can supply an absolute path (such as `/etc/passwd` or `/root/.ssh/authorized_keys`). The `version_dir.join()` will result in that absolute path, allowing the attacker to write arbitrary files anywhere on the file system with the permissions of the running backend process.

🎯 Potential Impact
An attacker can perform an Arbitrary File Write attack. This could lead to a complete system compromise by overwriting critical system files (e.g., SSH keys, cron jobs, or configuration files), Remote Code Execution (RCE), or a Denial of Service.

🛠️ Steps to Reproduce
1. Prepare a malicious multipart request targeting the `/api/aether/upload` endpoint.
2. In the `file` field of the multipart form data, specify the filename parameter as an absolute path, e.g., `filename="/tmp/pwned.txt"`.
3. Provide valid metadata fields (like `version`) to pass the other checks.
4. Provide a valid or weak fallback Authorization header (`Bearer update_me_please`).
5. Send the request.
6. Observe that the file is written to `/tmp/pwned.txt` instead of within the expected `STORAGE_DIR/version/` directory.

✅ Recommended Remediation
Implement filename sanitization before joining it to the storage directory. You should:
1. Extract only the base file name, ignoring any directory paths. For example, use `std::path::Path::new(&filename).file_name()`.
2. Validate that the resulting string does not contain path traversal characters (e.g., `..`, `/`, `\`).
3. Alternatively, generate a safe, random filename (like a UUID) on the server side and store the mapping in the database rather than trusting user input.

🔗 References
* Rust `PathBuf::join` documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
* OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
