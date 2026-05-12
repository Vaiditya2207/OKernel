Title: 🛡️ CRITICAL Arbitrary File Write: Unsanitized filename in Aether version upload handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains an Arbitrary File Write vulnerability due to the lack of sanitization on the `filename` provided in the multipart form data.
In Rust, `std::path::PathBuf::join` replaces the entire base path if the appended string is an absolute path. The `filename` extracted from `multipart.next_field()` is directly joined to `version_dir`:

```rust
// syscore/src/server/aether.rs
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

Because `filename` is attacker-controlled and unsanitized, an attacker can provide an absolute path (e.g., `/etc/passwd` or `/root/.ssh/authorized_keys`) as the `filename`. `PathBuf::join` will discard the `version_dir` and write the uploaded file contents directly to the attacker-specified absolute path on the host filesystem.

🎯 Potential Impact
An authenticated attacker (even using the weak default `AETHER_UPLOAD_KEY` of "update_me_please") can overwrite arbitrary files on the system with the permissions of the user running the `syscore` backend service. This can lead to Remote Code Execution (RCE) by overwriting `.ssh/authorized_keys`, cron jobs, or system binaries, leading to complete system compromise.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Provide the default authentication header: `Authorization: Bearer update_me_please`.
4. Include form fields for `version` (e.g., `1.0.0`), `description`, and `changelog`.
5. Include a file upload field with the name `file`. Set the filename parameter in the Content-Disposition header to an absolute path, such as `/tmp/pwned.txt`.
6. Send the request.
7. Observe that the file `pwned.txt` is created in `/tmp` containing the uploaded payload, instead of within the intended `storage/aether/1.0.0/` directory.

✅ Recommended Remediation
Implement strict path sanitization for the `filename` extracted from the multipart request before using it with `PathBuf::join`.
1. Reject any filename containing path separators (`/` or `\`).
2. Alternatively, extract only the final file component using `std::path::Path::new(&filename).file_name()`.
3. Ensure the resolved path remains within the intended storage directory bounds.

Example fix:
```rust
let safe_filename = std::path::Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .ok_or((StatusCode::BAD_REQUEST, "Invalid filename".to_string()))?;

let file_path = version_dir.join(safe_filename);
```

🔗 References
- Rust `PathBuf::join` documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
- OWASP Path Traversal / Arbitrary File Write: https://owasp.org/www-community/attacks/Path_Traversal

---

Title: 🛡️ CRITICAL Broken Auth: Weak default fallback for Aether upload key

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Authentication vulnerability due to a weak default fallback for the `AETHER_UPLOAD_KEY` environment variable. If the environment variable is not set, the application defaults to using `"update_me_please"`.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());

if auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```

This means that in any environment where the administrator forgets to explicitly set `AETHER_UPLOAD_KEY`, an attacker can bypass authentication by simply providing the known default key.

🎯 Potential Impact
An unauthenticated attacker can upload arbitrary files to the server using the default credentials, potentially overwriting existing releases, serving malicious updates to users, or combining this with other vulnerabilities (like arbitrary file write) to achieve Remote Code Execution.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting `AETHER_UPLOAD_KEY`.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Provide the default authentication header: `Authorization: Bearer update_me_please`.
4. Include necessary form fields (`version`, `file`, etc.).
5. Send the request.
6. Observe that the request is accepted (201 Created) instead of being rejected as unauthorized (401).

✅ Recommended Remediation
Fail securely when the required environment variable is missing. Do not provide a weak default fallback for credentials or secrets.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server misconfiguration: AETHER_UPLOAD_KEY not set".to_string()))?;
```
Alternatively, panic on startup if required secrets are not provided.

🔗 References
- OWASP Broken Authentication: https://owasp.org/www-project-top-10/2017/A2_2017-Broken_Authentication
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
