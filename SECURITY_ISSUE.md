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

Title: 🛡️ CRITICAL Broken Auth: Hardcoded default API key in Aether upload handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` contains a Broken Authentication vulnerability due to a hardcoded default API key.
When checking the authorization header, the code attempts to read the `AETHER_UPLOAD_KEY` environment variable. If it is missing, it falls back to the weak default credential `"update_me_please"` using `unwrap_or_else`:

```rust
// syscore/src/server/aether.rs
    let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());

    if auth_header != Some(&expected_key) {
        return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
    }
```

This effectively bypasses authentication if the deployment environment omits the `AETHER_UPLOAD_KEY` variable.

🎯 Potential Impact
An unauthenticated attacker can use the publicly known `"update_me_please"` credential to upload malicious files, create unauthorized releases, or overwrite existing system files. This leads to unauthorized data modification and potential Remote Code Execution.

🛠️ Steps to Reproduce
1. Ensure the `syscore` backend service is running without the `AETHER_UPLOAD_KEY` environment variable set.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Include the default authorization header: `Authorization: Bearer update_me_please`.
4. Send the request with valid multipart fields.
5. Observe that the server accepts the upload and returns a `201 CREATED` status instead of `401 UNAUTHORIZED`.

✅ Recommended Remediation
Remove the hardcoded fallback credential. The application should fail securely if a required secret is missing from the environment.
If the variable is missing, either log a startup error and terminate the application, or return a consistent `500 INTERNAL SERVER ERROR` or `401 UNAUTHORIZED` without falling back to a known weak key.

Example fix:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY").map_err(|_| {
    (StatusCode::INTERNAL_SERVER_ERROR, "Server misconfiguration: missing API key".to_string())
})?;
```

🔗 References
- OWASP Broken Authentication: https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
