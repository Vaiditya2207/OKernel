Title: 🛡️ CRITICAL Resource Exhaustion (DoS): Missing timeout in container execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` suffers from a Denial of Service (DoS) vulnerability due to an unbounded wait for container execution. When processing untrusted user code via the `/api/execute` endpoint, the system uses `self.docker.wait_container` without any timeout:

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because there is no timeout enforcement, an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python). The backend will spawn a container and indefinitely `await` its completion. By submitting multiple such requests, an attacker can exhaust all available CPU and memory resources on the host running the `syscore` service, leading to a complete system outage and rendering the service unavailable for legitimate users.

🎯 Potential Impact
An unauthenticated attacker can exhaust server resources (CPU, Memory, and Docker concurrent container limits) by submitting malicious scripts that never terminate. This will cause a complete Denial of Service (DoS) for the `/api/execute` endpoint and potentially crash the entire `syscore` backend.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a POST request to the `/api/execute` endpoint with a payload containing an infinite loop in Python:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Send multiple concurrent requests using this payload.
4. Observe that the requests never complete and the backend's resource usage (CPU/Memory) steadily increases, eventually leading to unresponsiveness or a crash.

✅ Recommended Remediation
Wrap the `self.docker.wait_container` future in a strict timeout using `tokio::time::timeout`. If the execution exceeds the allowed threshold (e.g., 5 seconds), the system should forcibly kill the container and return an error to the user indicating a timeout.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(5), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
        Some(Ok(res))
    },
    Ok(Some(Err(e))) => {
        tracing::warn!("[Job {}] Container wait error: {}", job_id, e);
        Some(Err(e))
    },
    Ok(None) => None,
    Err(_) => {
        tracing::warn!("[Job {}] Container execution timed out!", job_id);
        // Ensure cleanup_container handles stopping/killing if it's still running
        let _ = self.docker.stop_container(&id, None).await;
        None // Or return an explicit error to the caller
    }
};
```

🔗 References
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html