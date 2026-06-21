Title: 🛡️ CRITICAL Denial of Service: Unbounded Wait in Container Execution

🚨 Severity
CRITICAL

💡 Description
The `ContainerManager::execute` function in `syscore/src/docker/manager.rs` suffers from a Denial of Service (DoS) vulnerability due to an unbounded wait for code execution.

When user code is submitted via the `/api/execute` endpoint, the system creates a Docker container and starts it. It then waits for the container to finish using `docker.wait_container`.

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because `wait_container` has no timeout, an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python). The container will run indefinitely, and the worker thread handling the request will be permanently blocked awaiting completion. Repeated requests will rapidly exhaust the application's available worker threads, memory, and CPU resources, causing the backend service to become unresponsive to all users.

🎯 Potential Impact
An unauthenticated attacker can bring down the entire `syscore` backend service by submitting a few payloads designed to run endlessly. This leads to complete service unavailability (Denial of Service).

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send an execution request to the `/api/execute` endpoint containing an infinite loop:
   ```json
   POST /api/execute
   Content-Type: application/json

   {
     "language": "python",
     "code": "while True: pass"
   }
   ```
3. Observe that the request never returns a response.
4. Send multiple similar requests concurrently.
5. Observe that the backend becomes unresponsive and container instances are left running indefinitely, consuming server resources.

✅ Recommended Remediation
Introduce an explicit timeout when waiting for the container to exit. Use `tokio::time::timeout` around the `wait_container` call to enforce a maximum execution duration (e.g., 5-10 seconds). If the timeout is reached, proactively kill or stop the container and return an appropriate "Execution Timeout" error to the user.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(5), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out", job_id);
        // Ensure cleanup removes the stuck container (e.g., using force: true)
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
- Rust Tokio Timeouts: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html