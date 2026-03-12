Title: 🛡️ CRITICAL Arbitrary File Write: Unsanitized filename in Aether Upload

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a path traversal vulnerability. It reads the `filename` directly from the `multipart` field and joins it to a base directory (`version_dir.join(&filename)`). Because `axum::extract::Multipart` does not sanitize filenames, an attacker can submit a filename containing `../` or an absolute path (e.g., `/etc/passwd`). In Rust, `std::path::PathBuf::join` completely replaces the base path if the appended string is absolute.

Compounding this issue is broken authentication. The endpoint relies on `AETHER_UPLOAD_KEY`, falling back to a weak default (`update_me_please`) if the variable is unset. This allows unauthenticated external attackers to exploit this issue easily.

Lines 149-165 extract the `filename`:
```rust
    while let Some(field) = multipart.next_field().await.map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))? {
        let name = field.name().unwrap_or("").to_string();

        if name == "file" {
            filename = field.file_name().map(|s| s.to_string());
```

Lines 184-185 write to the vulnerable path:
```rust
    let file_path = version_dir.join(&filename);
    tokio_fs::write(&file_path, &file_bytes).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
```

🎯 Potential Impact
An unauthenticated external attacker can upload malicious files to arbitrary locations on the server, potentially overwriting critical system files, binaries, or configuration files, leading to full Remote Code Execution (RCE) or complete system compromise.

🛠️ Steps to Reproduce
1. Prepare a malicious multipart form request where the `file` field has the filename `/tmp/pwned.txt`.
2. Send a POST request to `/api/v1/aether` with the Authorization header `Bearer update_me_please` (if `AETHER_UPLOAD_KEY` is not set).
3. Observe that `pwned.txt` is written to `/tmp/pwned.txt`, ignoring the `storage/aether/<version>` directory entirely.

✅ Recommended Remediation
1. **Sanitize the filename:** Extract only the final component of the provided filename and ensure it does not contain invalid characters. Rust's `std::path::Path::new(&filename).file_name()` can extract the file component, but further validation is needed.
2. **Remove Default Key:** Remove the weak fallback key (`update_me_please`). Fail securely if `AETHER_UPLOAD_KEY` is not configured in production environments.

🔗 References
* [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
* [Rust `PathBuf::join` documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join)