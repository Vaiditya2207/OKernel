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

Title: 🛡️ CRITICAL Broken Auth: Hardcoded/Weak default fallback credential in Aether upload handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` uses a weak, hardcoded default API key (`"update_me_please"`) as a fallback if the `AETHER_UPLOAD_KEY` environment variable is not set.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

This ensures that if the service is deployed without properly configuring the `AETHER_UPLOAD_KEY` secret, an attacker can easily bypass authentication by guessing or discovering this default key in the source code.

🎯 Potential Impact
An unauthenticated external attacker can use the default credential `"update_me_please"` to authenticate to the `/api/v1/aether` upload endpoint. This allows them to upload arbitrary application versions, bundles, and patches to the backend, effectively taking control of the software distribution channel. When combined with the Arbitrary File Write vulnerability, this leads to immediate remote code execution on the server.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting the `AETHER_UPLOAD_KEY` environment variable.
2. Send a multipart POST request to the `/api/v1/aether` endpoint.
3. Include the header `Authorization: Bearer update_me_please`.
4. Observe that the server accepts the upload request and processes it, instead of rejecting it with a 401 Unauthorized status.

✅ Recommended Remediation
Remove the fallback default credential. The service should reject requests securely if the required environment variable is missing, or preferably fail to start.

Example fix:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server configuration error".to_string()))?;
```

🔗 References
- OWASP Broken Access Control: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
