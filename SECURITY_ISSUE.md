Title: 🛡️ CRITICAL DoS: Unbounded Docker Container Execution allows Server Exhaustion

🚨 Severity
CRITICAL

💡 Description
The `syscore` backend service exposes a code execution endpoint at `/api/execute` which allows running arbitrary, untrusted Python or C++ code via Docker containers.
In `syscore/src/docker/manager.rs`, the `execute` function uses `docker.wait_container` on the user's execution container but fails to implement any timeout logic:

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because there is no timeout mechanism protecting `wait_container`, an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python). The container will run indefinitely, and the backend async task waiting on it will hang forever. The container limits CPU usage but still consumes memory and blocks async task execution. Repeated requests will eventually lead to complete resource exhaustion (memory starvation and Docker connection pool exhaustion), causing a complete Denial of Service.

🎯 Potential Impact
An unauthenticated attacker can trivially cause a complete Denial of Service (DoS) of the `syscore` backend by sending multiple requests to the `/api/execute` endpoint containing infinite loops. This will exhaust server memory and async worker capacity, bringing down the code execution service for all users.

🛠️ Steps to Reproduce
1. Start the `syscore` backend server.
2. Send an HTTP POST request to `/api/execute` with the following JSON payload containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Observe that the API request never completes and hangs indefinitely.
4. Use `docker ps` on the host to observe that the `okernel-job-<uuid>` container runs forever.
5. Send multiple such requests to exhaust system resources, leading to a Denial of Service.

✅ Recommended Remediation
Implement a strict execution timeout around the `wait_container` operation using `tokio::time::timeout`. If the timeout is reached, explicitly kill and remove the container to free up resources, and return an error to the user.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let timeout_duration = Duration::from_secs(10); // 10 seconds timeout

match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out after {:?}", job_id, timeout_duration);
        let _ = self.docker.kill_container::<String>(&id, None).await;
        // Proceed to cleanup
    }
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Denial of Service Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html
