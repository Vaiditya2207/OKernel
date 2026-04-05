Title: 🛡️ CRITICAL DoS: Unbounded wait on untrusted Docker execution

🚨 Severity
CRITICAL

💡 Description
The `ContainerManager::execute` function in `syscore/src/docker/manager.rs` does not enforce a timeout when waiting for the Docker container to finish execution. Specifically, it calls:

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because user-submitted code can contain infinite loops (e.g., `while True: pass` in Python), the container will never exit on its own. As a result, the `syscore` backend will wait indefinitely, consuming resources for the container (CPU, memory, process entries) and occupying connection streams. An attacker can repeatedly submit infinite loop scripts, leading to complete resource exhaustion and Denial of Service.

🎯 Potential Impact
An unauthenticated attacker can submit multiple payloads with infinite loops to the `/api/execute` endpoint. This will cause the backend to spawn containers that never terminate. Eventually, the host will run out of system resources (memory, PIDs), bringing down the entire `syscore` backend and any co-hosted services.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to the `/api/execute` endpoint containing an infinite loop payload. For example, for Python:
   ```json
   {
       "lang": "Python",
       "code": "while True:\n    pass"
   }
   ```
3. Observe that the request never returns a response.
4. Check the host's running Docker containers (`docker ps`). Observe that the `okernel-job-<uuid>` container is running indefinitely.
5. Repeat the request multiple times to observe resource consumption growing without bounds until the service becomes unresponsive.

✅ Recommended Remediation
Implement an explicit timeout when waiting for the container to finish. If the container does not exit within the designated timeout (e.g., 5-10 seconds), forcefully kill and remove the container, and return an error to the user indicating a timeout.

Example using `tokio::time::timeout`:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Container execution timed out", job_id);
        // Clean up the container
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};

if let Some(Ok(res)) = wait_res {
    tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
} else {
    tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Resource Exhaustion (DoS): https://owasp.org/www-community/attacks/Denial_of_Service
