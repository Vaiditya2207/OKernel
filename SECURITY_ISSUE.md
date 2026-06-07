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

Title: 🛡️ CRITICAL Broken Auth: Weak default fallback for Aether upload authentication

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Authentication vulnerability due to an insecure fallback for the `AETHER_UPLOAD_KEY` environment variable. When the environment variable is missing, the application defaults to the weak, hardcoded credential `"update_me_please"`.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());

if auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```
If a server administrator forgets to set `AETHER_UPLOAD_KEY`, the upload endpoint becomes accessible to anyone who knows or guesses this hardcoded string.

🎯 Potential Impact
An unauthorized attacker can bypass authentication by using the default token. Since the endpoint handles file uploads (and is also vulnerable to Arbitrary File Write), this can lead to remote code execution (RCE) and full compromise of the backend service and host system.

🛠️ Steps to Reproduce
1. Ensure the `syscore` backend service is running in an environment where `AETHER_UPLOAD_KEY` is not set.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Set the authorization header: `Authorization: Bearer update_me_please`.
4. Observe that the request is accepted and the file upload proceeds successfully, instead of rejecting the request with a `401 UNAUTHORIZED`.

✅ Recommended Remediation
Remove the insecure default fallback. If the required environment variable for authentication is not set, the application should fail securely. This can be done by returning an error at runtime or, ideally, failing to start the application.

Example fix for runtime enforcement:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server misconfiguration: AETHER_UPLOAD_KEY not set".to_string()))?;

if auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```

🔗 References
- OWASP Broken Authentication: https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication
- Fail-Safe Defaults Principle: https://owasp.org/www-community/Fail_safely
