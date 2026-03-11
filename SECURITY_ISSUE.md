🛡️ CRITICAL Arbitrary File Write: Unsanitized filename in /api/v1/aether upload

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains an arbitrary file write vulnerability due to unsanitized filenames. Specifically, on line 159 when extracting the filename from the multipart form field: `filename = field.file_name().map(|s| s.to_string());`, and then later on line 192 when writing the file: `let file_path = version_dir.join(&filename);`. Because the `filename` variable is completely unsanitized, an attacker can provide a filename containing directory traversal sequences (e.g., `../../../../etc/passwd` or absolute paths like `/etc/shadow`) which `PathBuf::join` will blindly resolve. In Rust, if the second argument to `PathBuf::join` is an absolute path, it replaces the base path entirely. This allows an authenticated attacker to write arbitrary files anywhere on the file system with the permissions of the `syscore` process.

🎯 Potential Impact
An attacker with the update key (which currently falls back to a weak default `update_me_please` if `AETHER_UPLOAD_KEY` is not set, as seen on line 142) can write arbitrary files to the server's filesystem. This could lead to Remote Code Execution (RCE) by overwriting critical system files (like crontabs, SSH authorized_keys, or service binaries), denial of service by corrupting configuration files, or data destruction.

🛠️ Steps to Reproduce
1. Prepare a malicious payload file (e.g., a reverse shell script).
2. Construct a multipart/form-data request to POST `/api/v1/aether` (assuming this is the endpoint mapped to `upload_handler`).
3. Set the `Authorization` header to `Bearer update_me_please`.
4. Include valid `version` (e.g., "1.0.0"), `description`, and `changelog` text fields.
5. In the `file` field, provide the malicious payload and set the filename parameter in the Content-Disposition header to an absolute path or path traversal string, e.g., `filename="/tmp/pwned.txt"` or `filename="../../../../../tmp/pwned.txt"`.
6. Send the request. Observe that the file is written to `/tmp/pwned.txt` instead of the intended `storage/aether/1.0.0/` directory.

✅ Recommended Remediation
Implement strict filename sanitization before joining it with the `version_dir`. Do not trust the `filename` provided by the client.
- Strip all path separators (`/`, `\`) and directory traversal sequences (`..`).
- A robust approach is to only take the file extension from the provided filename (if even that) and generate a random UUID or safe, predictable name for the stored file, while keeping the original filename only in the `metadata.json` for display purposes.
- If preserving the filename is necessary, use a library or custom logic to ensure it only contains safe alphanumeric characters and does not contain any path components. For example, ensure that `Path::new(&filename).file_name() == Some(OsStr::new(&filename))`.

🔗 References
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
- Rust `PathBuf::join` documentation highlighting absolute path behavior: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
