Title: 🛡️ CRITICAL DoS: Unbounded Wait in Docker Container Execution

🚨 Severity
CRITICAL

💡 Description
In `syscore/src/docker/manager.rs`, the `execute` method spawns an ephemeral Docker container to run unauthenticated, user-submitted code. However, it waits for the container to exit using `self.docker.wait_container::<String>(&id, None).next().await;` on line 227 without enforcing any timeout.

Because the `/api/execute` endpoint accepts arbitrary code (e.g., Python or C++) from the frontend without authentication, an attacker can submit code containing an infinite loop (e.g., `while True: pass`). The backend will spawn the container and `await` its completion indefinitely.

🎯 Potential Impact
An attacker can easily exhaust the server's compute resources by sending multiple requests with infinite loops. Each request will lock up an execution task and leave a running container consuming memory and CPU until the server hits its limits (Denial of Service). Even though memory is capped at 256MB per container, a moderate number of concurrent malicious executions will deplete system resources entirely, taking the application offline.

🛠️ Steps to Reproduce
1. Start the backend service.
2. Send a POST request to `/api/execute` with the payload:
   ```json
   {
     "language": "python",
     "code": "while True:\n    pass"
   }
   ```
3. Observe that the request never returns, and the Docker container runs indefinitely, consuming 100% of its allotted CPU limit.
4. Repeat this multiple times to exhaust server resources.

✅ Recommended Remediation
Wrap the `wait_container` operation in a timeout using `tokio::time::timeout`. If the execution exceeds a reasonable timeframe (e.g., 5-10 seconds), kill the container and return an error to the user indicating a timeout.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = timeout(Duration::from_secs(10), wait_future).await;

match wait_res {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out, killing container...", job_id);
        // Ensure container is stopped/killed
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- Tokio Timeout: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
