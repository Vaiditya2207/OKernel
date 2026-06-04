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
Title: 🛡️ CRITICAL Arbitrary File Write & Broken Auth: Unsanitized filenames and weak default credentials in Aether upload_handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` is vulnerable to two critical issues:
1. **Broken Auth**: On line 315, the handler uses `unwrap_or_else` to supply a weak default API key (`update_me_please`) if the `AETHER_UPLOAD_KEY` environment variable is not set.
2. **Arbitrary File Write / Path Traversal**: Starting from line 387, user-controlled filenames (`filename`, `bundle_filename`, `patch_filename`) extracted from multipart form data are passed directly to `version_dir.join()` without any sanitization. This allows an attacker to upload files to arbitrary locations on the filesystem by including path traversal sequences (e.g., `../../`) in the filename.

🎯 Potential Impact
An unauthorized attacker can trivially authenticate using the default key and leverage the path traversal vulnerability to write or overwrite arbitrary files on the server with the permissions of the running application, potentially leading to Remote Code Execution (RCE) or complete system compromise.

🛠️ Steps to Reproduce
1. Send a POST request to `/api/v1/aether/upload` with the `Authorization: Bearer update_me_please` header.
2. Include a multipart form data payload with a file field where the filename is `../../../tmp/pwned.txt`.
3. Observe that the file is written to `/tmp/pwned.txt` on the server instead of the intended version directory.

✅ Recommended Remediation
- **Broken Auth**: Remove the fallback default key. The application should fail securely and refuse to start or reject requests if `AETHER_UPLOAD_KEY` is missing.
- **Arbitrary File Write**: Sanitize all user-supplied filenames before using them in `PathBuf::join`. For example, use `std::path::Path::new(&filename).file_name().and_then(|name| name.to_str())` to extract only the final file component and discard any directory traversal sequences.

🔗 References
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
- OWASP Broken Authentication: https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/
