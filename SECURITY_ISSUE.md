🛡️ CRITICAL Injection: Arbitrary File Write via Unsanitized Multipart Filename

## 🚨 Severity
CRITICAL

## 💡 Description
An Arbitrary File Write vulnerability exists in the `upload_handler` function located in `syscore/src/server/aether.rs`.
The `axum::extract::Multipart` library extracts the filename from the uploaded file (around line 159: `filename = field.file_name().map(|s| s.to_string());`). This raw, unsanitized user input is later concatenated with the base directory path using `PathBuf::join` (line 192: `let file_path = version_dir.join(&filename);`) and then written to disk (`tokio_fs::write`).

Because `PathBuf::join` in Rust replaces the entire path if the appended string is an absolute path (e.g., `/etc/passwd`), an attacker can upload a file with an absolute path or relative path traversal sequences (`../`) to overwrite arbitrary files on the system where the `syscore` backend service is running. This is compounded by the fact that the endpoint authentication falls back to a weak default key (`update_me_please`) if the `AETHER_UPLOAD_KEY` environment variable is not explicitly set.

## 🎯 Potential Impact
An attacker with network access to the API could exploit this vulnerability to write or overwrite critical system files. For example, they could:
* Overwrite `/etc/passwd` or `/etc/shadow` (if running as root, though unlikely, still dangerous).
* Plant a webshell or executable script in a known directory to gain remote code execution (RCE).
* Overwrite critical application configuration files to alter the backend's behavior.
* Cause a Denial of Service (DoS) by filling up the disk or corrupting vital system binaries.

## 🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Ensure you have the fallback upload key (`update_me_please`) or know the actual key.
3. Construct a multipart POST request to the `/api/v1/aether` (or the mapped upload route) endpoint.
4. Set the `Authorization` header to `Bearer update_me_please`.
5. Include the required fields: `version` (e.g., `1.0.0`), `description`, `changelog`.
6. Include the `file` field, but manipulate the filename parameter in the `Content-Disposition` header to contain a traversal payload. For example: `filename="../../../../../tmp/pwned.txt"`.
7. Send the request.
8. Check the `/tmp` directory on the server. You will find that `pwned.txt` has been created with the contents of the uploaded file, bypassing the intended `storage/aether` directory.

## ✅ Recommended Remediation
Implement strict filename sanitization before joining the path. Do not trust the filename provided by the client.

* **Option 1 (Generate Random Filename):** Ignore the client-provided filename entirely and generate a UUID for the stored file. Store the original filename in the database or metadata if needed for display purposes.
* **Option 2 (Strict Sanitization):** If you must use the original filename, strip all path components and validate it against a strict whitelist of allowed characters.
  ```rust
  // Example of extracting just the file name component
  if let Some(name) = field.file_name() {
      if let Some(safe_name) = std::path::Path::new(name).file_name() {
          filename = Some(safe_name.to_string_lossy().into_owned());
      } else {
           // Handle invalid filename
      }
  }
  ```
* **Defense in Depth:** Ensure the application runs with the least privilege necessary, so even if an arbitrary write occurs, the damage is contained to the application's user space. Force administrators to set a strong `AETHER_UPLOAD_KEY` on startup by failing to start if the environment variable is missing, rather than using a hardcoded default.

## 🔗 References
* [OWASP Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
* [Rust std::path::PathBuf::join documentation](https://doc.rust-lang.org/std/path/struct.PathBuf.html#method.join) (Note the behavior when appending absolute paths).