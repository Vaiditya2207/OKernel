Title: 🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Filename

🚨 Severity
CRITICAL

💡 Description
The Aether upload endpoint (`upload_handler`) takes `filename` directly from the multipart form data and uses it to construct a file path without sanitization. In Rust, `PathBuf::join` replaces the entire path if the appended segment is an absolute path. Additionally, relative paths with directory traversal sequences (e.g., `../`) could traverse outside the intended storage directory. This allows an authenticated attacker to write arbitrary files anywhere on the filesystem that the application process has access to.

Vulnerable code location: `syscore/src/server/aether.rs`, specifically lines where `filename` is extracted and joined:
```rust
filename = field.file_name().map(|s| s.to_string());
// ...
let file_path = version_dir.join(&filename);
tokio_fs::write(&file_path, &file_bytes).await...
```

🎯 Potential Impact
An attacker with upload privileges could overwrite critical system files, inject malicious executables, or modify configuration files. This can lead to Remote Code Execution (RCE) or a complete compromise of the system running the backend service.

🛠️ Steps to Reproduce
1. Retrieve or know the upload key (defaults to "update_me_please" if not set).
2. Send a multipart POST request to the upload endpoint with `version` set to a valid string (e.g., "1.0.0").
3. Include a `file` field in the multipart data with a crafted `filename` such as `/tmp/pwned.txt` or `../../../../tmp/pwned.txt`.
4. Observe that the file is written to the absolute path `/tmp/pwned.txt` (or relative traversal path) outside the intended `storage/aether/<version>/` directory.

✅ Recommended Remediation
Implement strict path sanitization on the `filename` extracted from the multipart form before using it in filesystem operations. Only accept the base name of the file by stripping any directory components.

```rust
use std::path::Path;

let safe_filename = Path::new(&filename)
    .file_name()
    .and_then(|name| name.to_str())
    .unwrap_or("default_filename");

let file_path = version_dir.join(safe_filename);
```

🔗 References
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Rust `Path::join` Documentation](https://doc.rust-lang.org/std/path/struct.Path.html#method.join)
