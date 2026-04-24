Title: 🛡️ CRITICAL DoS: Missing timeout in Docker container execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` orchestrates untrusted user code execution by spawning Docker containers. However, it waits for the container to finish using `self.docker.wait_container::<String>(&id, None).next().await;` without applying any explicit timeout mechanism.
This means that if malicious code submitted via the execution API contains an infinite loop or blocks indefinitely, the `wait_container` await point will never return. The backend will hang on this request, and the Docker container will run indefinitely, exhausting server resources over time.

🎯 Potential Impact
An attacker can submit code with infinite loops (e.g., `while True: pass` in Python), causing a Denial of Service (DoS). By repeatedly sending such requests, the attacker can quickly exhaust server memory, CPU, and available connection/worker threads, rendering the application and API completely unavailable.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a request to the code execution endpoint that triggers `ContainerManager::execute`.
3. Provide a payload that executes an infinite loop. For Python:
   ```json
   {
     "language": "python",
     "code": "while True: pass"
   }
   ```
4. Observe that the API request hangs indefinitely and never returns.
5. Check the system's Docker processes using `docker ps` and note that the container `okernel-job-<uuid>` continues to run indefinitely, consuming CPU resources.

✅ Recommended Remediation
Implement an explicit timeout when waiting for the container to finish using `tokio::time::timeout`. If the timeout expires, the function should log the event, stop the container, and return an error to prevent unbounded execution.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

let wait_future = self.docker.wait_container::<String>(&id, None).next();
// Set a reasonable execution timeout, e.g., 10 seconds.
match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out", job_id);
        // Cleanup routine will handle stopping/removing the container
    }
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
