Title: 🛡️ [CRITICAL] Denial of Service (DoS): Unbounded Container Execution via `/api/execute`

🚨 Severity
CRITICAL

💡 Description
The unauthenticated API endpoint `/api/execute` located in `syscore/src/server/routes.rs` allows execution of untrusted user code (Python/C++) using Docker containers. The execution logic in `syscore/src/docker/manager.rs` awaits the container completion using `docker.wait_container::<String>(&id, None).next().await;` on line 227.

Because there is no explicit timeout wrapping this `.await` call, malicious or poorly written user code (such as an infinite loop or `time.sleep(99999)`) will cause the container to run indefinitely. This will tie up server resources, leaving the background Docker process and the Rust `execute` future pending forever.

🎯 Potential Impact
An attacker could repeatedly submit code containing infinite loops to the `/api/execute` endpoint. This will quickly exhaust the system's process limits, memory, and CPU (even with the 1 CPU/256MB limit), leading to a complete Denial of Service (DoS) for the entire application, preventing legitimate users from executing code.

🛠️ Steps to Reproduce
1. Send a POST request to the `/api/execute` endpoint without authentication.
2. Input the following JSON payload:
   ```json
   {
     "language": "python",
     "code": "while True: pass"
   }
   ```
3. Observe that the API request never completes, and the Docker container remains running on the host system indefinitely. Repeated requests will accumulate orphaned containers and exhaust resources.

✅ Recommended Remediation
Wrap the `wait_container` future with a timeout using `tokio::time::timeout`. For example:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Container execution timed out", job_id);
        // Ensure the container is forcefully removed
        let _ = self.docker.remove_container(&id, Some(bollard::container::RemoveContainerOptions {
            force: true,
            ..Default::default()
        })).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- [OWASP: Denial of Service (DoS)](https://owasp.org/www-community/attacks/Denial_of_Service)
- [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html)
