Title: 🛡️ CRITICAL SSRF/Insecure Deserialization: Arbitrary File Write / Path Traversal in `/api/v1/aether`

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` contains an Arbitrary File Write vulnerability due to the lack of sanitization on the `filename` provided via a multipart form upload.

At lines 158-159, the application extracts the `filename` from the user-controlled `file` field without any sanitization:
```rust
if name == "file" {
    filename = field.file_name().map(|s| s.to_string());
```

Later, at line 192, this raw `filename` is appended to the `version_dir` path using `PathBuf::join`:
```rust
let file_path = version_dir.join(&filename);
```

In Rust, `std::path::PathBuf::join` replaces the base path entirely if the appended string is an absolute path (e.g., starting with `/`). Moreover, if the filename contains directory traversal sequences (`../`), it can traverse out of the intended `storage/aether/<version>` directory. Because the application then calls `tokio_fs::write(&file_path, &file_bytes)` on line 193, an attacker can write arbitrary contents to any location on the file system writable by the application process.

🎯 Potential Impact
An attacker with upload privileges could write or overwrite arbitrary files on the system. This could lead to a complete system compromise by overwriting critical configuration files, executable binaries, or dropping an SSH key into an authorized_keys file.

🛠️ Steps to Reproduce
1. Prepare a malicious payload (e.g., an unauthorized SSH key or a shell script).
2. Create a multipart/form-data request to the Aether upload endpoint (`/api/v1/aether`).
3. Set the `version` field to a valid version string (e.g., `1.0.0`) to pass the initial traversal checks.
4. Set the `filename` attribute in the `file` part's Content-Disposition header to an absolute path, for example: `filename="/root/.ssh/authorized_keys"`.
5. Provide the malicious payload as the file content.
6. Send the request with the required Authorization header.
7. Observe that the payload has been written to `/root/.ssh/authorized_keys`, completely bypassing the `storage/aether` directory constraint.

✅ Recommended Remediation
Implement strict sanitization for the extracted `filename`. Do not rely solely on the user-provided name.
1. The most secure approach is to generate a random or standardized filename on the server (e.g., using UUIDs) and store the original filename in metadata if needed.
2. If the user-provided filename must be used, strip all path components from it, leaving only the base filename. In Rust, you can do this by converting the string to a `Path`, calling `.file_name()`, and then converting it back to a string.
3. Explicitly check that the final joined `file_path` starts with the intended base directory (`version_dir`) before performing any disk operations.

🔗 References
- Rust `PathBuf::join` Documentation: https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
