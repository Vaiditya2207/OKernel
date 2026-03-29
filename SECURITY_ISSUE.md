Title: 🛡️ CRITICAL Denial of Service (DoS): Unbounded Execution of Untrusted Code in Docker Containers

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` is responsible for running untrusted user-submitted code in ephemeral Docker containers via the `/api/execute` endpoint. However, the execution flow waits indefinitely for the container to finish without enforcing a timeout.

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because there is no timeout mechanism (such as `tokio::time::timeout`), an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python). The container will run indefinitely, and the backend service will permanently block the async task waiting for it to complete.

🎯 Potential Impact
An unauthenticated attacker can continuously submit payloads containing infinite loops to the `/api/execute` endpoint. While each container is limited to 256MB of RAM and 1 CPU, an attacker can quickly exhaust the server's CPU, memory, Docker connection pool, or process limits, leading to a complete Denial of Service (DoS) for the entire application. Legitimate users will be unable to execute code.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to the `/api/v1/execute` endpoint with a payload containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Observe that the HTTP request never receives a response (until the client times out) and the container remains running indefinitely on the host.
4. Send multiple such requests to exhaust server resources.

✅ Recommended Remediation
Wrap the `docker.wait_container` operation in a timeout (e.g., `tokio::time::timeout`). If the execution exceeds the maximum allowed time (e.g., 5 seconds), the container should be forcefully stopped/killed, and an error should be returned to the client.

Example fix:
```rust
use tokio::time::{timeout, Duration};

// 6. Wait for execution to finish with a 5-second timeout
let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(5), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out!", job_id);
        // Clean up the running container
        let _ = self.docker.stop_container(&id, None).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- OWASP DoS Vulnerabilities: https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
