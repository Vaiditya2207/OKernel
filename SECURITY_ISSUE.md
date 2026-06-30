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

Title: 🛡️ CRITICAL Broken Auth: Weak Default Fallback for AETHER_UPLOAD_KEY

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Auth vulnerability due to a weak default fallback for the `AETHER_UPLOAD_KEY` environment variable.
When extracting the expected authentication key, the code uses `unwrap_or_else` to supply a hardcoded string `"update_me_please"` if the environment variable is not set.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());

if auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```
If the backend is deployed without explicitly configuring the `AETHER_UPLOAD_KEY` environment variable, the endpoint will silently accept the known hardcoded password `"update_me_please"`.

🎯 Potential Impact
An attacker can easily bypass authentication on the Aether upload endpoint by providing the known default credential (`Authorization: Bearer update_me_please`). This grants them unauthorized access to upload new release bundles, patches, and metadata. By publishing a malicious release, an attacker could compromise all users downloading updates from this channel (supply chain attack).

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting the `AETHER_UPLOAD_KEY` environment variable.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Include the default authorization header: `Authorization: Bearer update_me_please`.
4. Provide dummy valid fields for `version` (e.g., `9.9.9`), `file`, etc.
5. Send the request.
6. Observe that the server responds with a `201 CREATED` status and accepts the upload, demonstrating successful authentication bypass.

✅ Recommended Remediation
Remove the default fallback for the authentication key. The application should fail securely if the environment variable is missing. It is recommended to validate the presence of the environment variable at startup and panic or exit if it is missing. At the handler level, return an error if it cannot be retrieved.

Example fix at handler level:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY").map_err(|_| {
    (StatusCode::INTERNAL_SERVER_ERROR, "Server misconfiguration: missing API key".to_string())
})?;
```

🔗 References
- OWASP Broken Access Control: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
- CWE-1188: Initialization of a Resource with an Insecure Default: https://cwe.mitre.org/data/definitions/1188.html
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
