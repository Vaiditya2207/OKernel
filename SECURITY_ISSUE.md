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

Title: 🛡️ CRITICAL Denial of Service: Missing execution timeout in Docker container execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` launches a Docker container to run untrusted code submitted by the user. However, when waiting for the container to finish, it calls `self.docker.wait_container::<String>(&id, None).next().await;` without any timeout mechanism.

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

If the submitted code contains an infinite loop or blocks indefinitely, the `wait_container` future will never resolve, keeping the execution task alive and the container running forever.

🎯 Potential Impact
An attacker can submit malicious code (e.g., `while True: pass` in Python) to the `/api/execute` endpoint. This code will run indefinitely in the Docker container. An attacker can repeatedly send these requests to exhaust system resources (CPU, Memory, and Docker container limits on the host system). This leads to a Denial of Service (DoS) where the backend is no longer able to process legitimate execution requests, and potentially crashes the entire host system due to resource exhaustion.

🛠️ Steps to Reproduce
1. Start the backend service.
2. Send a POST request to `/api/execute` containing an infinite loop payload for Python (e.g., `while True: pass`).
3. Observe that the request never completes and the backend holds the connection open indefinitely.
4. Run `docker ps` on the host machine and observe that the container remains running without terminating.
5. Send multiple such requests and observe host CPU/Memory usage increasing unbounded until the system crashes or becomes unresponsive.

✅ Recommended Remediation
Implement an explicit timeout when awaiting `wait_container` to ensure that execution tasks are guaranteed to finish and containers are terminated if they exceed the time limit.

Example fix using `tokio::time::timeout`:
```rust
use tokio::time::{timeout, Duration};

// ...

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out, killing container", job_id);
        // Ensure container is stopped/killed before proceeding to cleanup
        let _ = self.docker.kill_container(&id, None).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- Tokio Timeout documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP DoS Resource Exhaustion: https://owasp.org/www-community/attacks/Denial_of_Service
