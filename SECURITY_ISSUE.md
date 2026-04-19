Title: 🛡️ CRITICAL Denial of Service: Unbounded Wait on Untrusted Container Execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` does not enforce a timeout when waiting for a Docker container to finish execution. Specifically, `docker.wait_container` is awaited indefinitely:

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because the `/api/execute` endpoint processes unauthenticated requests to run user-provided code, a malicious actor can submit code containing an infinite loop (e.g., `while True: pass` in Python). The backend will spawn a container and wait indefinitely for it to complete without ever releasing the associated async task or Docker container resources.

🎯 Potential Impact
An unauthenticated attacker can submit multiple requests with infinite loops, tying up async worker threads and exhausting Docker resources (such as maximum concurrent containers or server memory/CPU). This will lead to a complete Denial of Service (DoS) for the execution backend and the entire application.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a POST request to the `/api/execute` endpoint.
3. Provide the JSON payload: `{"language": "python", "code": "while True: pass"}`.
4. Send the request.
5. Observe that the API request hangs indefinitely and the associated Docker container runs continuously without being terminated or timing out.

✅ Recommended Remediation
Wrap the `wait_container` future with an explicit timeout using `tokio::time::timeout`. If the timeout expires, forcibly stop and remove the container.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out", job_id);
        let _ = self.docker.stop_container(&id, None).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
