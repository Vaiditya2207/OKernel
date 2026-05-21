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
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Authentication vulnerability. If the `AETHER_UPLOAD_KEY` environment variable is not set, it falls back to a weak, hardcoded default key (`"update_me_please"`).

```rust
// syscore/src/server/aether.rs, line 315
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

This means that if the server is deployed without explicitly configuring this secret, anyone can authenticate and upload new versions of the software.

🎯 Potential Impact
An unauthenticated attacker can use the default credential `"update_me_please"` to bypass the authorization check. This allows them to upload malicious software updates (DMGs, bundles, or patches) to the Aether release channels, which could then be distributed to all end-users, leading to mass compromise (Supply Chain Attack).

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting the `AETHER_UPLOAD_KEY` environment variable.
2. Send a POST request to the `/api/v1/aether` upload endpoint.
3. Provide the Authorization header: `Authorization: Bearer update_me_please`.
4. Observe that the request is accepted (Status 201 Created) instead of rejected (Status 401 Unauthorized).

✅ Recommended Remediation
Remove the weak default fallback. The application should fail securely if the expected authentication key is missing.
Either panic on startup if the key is missing, or return an error/deny all requests if it is not configured.

Example fix (failing securely at request time):
```rust
let expected_key = match std::env::var("AETHER_UPLOAD_KEY") {
    Ok(key) => key,
    Err(_) => {
        tracing::error!("AETHER_UPLOAD_KEY is not set. Rejecting upload request.");
        return Err((StatusCode::INTERNAL_SERVER_ERROR, "Server authentication misconfigured".to_string()));
    }
};
```

🔗 References
- OWASP Broken Authentication: https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
