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

Title: 🛡️ CRITICAL DoS: Unbounded Wait in Docker Container Execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` orchestrates the execution of untrusted user code inside a Docker container. However, it fails to enforce an execution timeout when waiting for the container to finish. Specifically, it uses `.next().await` on the stream returned by `docker.wait_container` without wrapping it in a timeout:

```rust
// syscore/src/docker/manager.rs, around line 227
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because the `/api/execute` endpoint is unauthenticated and accepts arbitrary code (e.g., Python or C++ scripts containing infinite loops like `while True: pass`), an attacker can submit code that never exits. The backend task will hang indefinitely waiting for the container to terminate, leading to unbounded resource consumption (both container compute resources and backend Tokio worker threads).

🎯 Potential Impact
An attacker could repeatedly submit infinite loop payloads to the `/api/execute` endpoint. This will quickly exhaust the server's Tokio async workers, Docker container limits, and CPU/Memory resources, resulting in a complete Denial of Service (DoS) for all backend services.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to the `/api/execute` endpoint containing an infinite loop payload in Python:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Observe that the API request never completes and hangs indefinitely.
4. Send multiple concurrent requests to exhaust worker threads.
5. Verify that the Docker container continues running indefinitely and the backend becomes unresponsive.

✅ Recommended Remediation
Implement an explicit timeout when waiting for the container to complete. Wrap the `.next().await` call in `tokio::time::timeout` and ensure the container is forcefully killed if it exceeds the allowed execution time limit.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out, killing container", job_id);
        // Container will be cleaned up in the cleanup step
        None
    }
};
```

🔗 References
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
