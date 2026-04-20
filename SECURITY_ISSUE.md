Title: 🛡️ CRITICAL Denial of Service: Unbounded Container Execution via Missing Timeout

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` relies on `docker.wait_container` to await the completion of a Docker container running user-provided code. However, there is no timeout applied to this wait operation:

```rust
// syscore/src/docker/manager.rs (line 227)
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because this endpoint processes untrusted code (such as infinite loops like `while True: pass` in Python), an attacker can submit code that never halts. This causes the `.await` to hang indefinitely. Since resources (Docker container memory/CPU) are not reclaimed until the container finishes and is explicitly cleaned up, and the concurrent connections are held open, an attacker can easily exhaust server resources (CPU, memory, Docker connection pool) by submitting multiple non-terminating code payloads.

🎯 Potential Impact
An unauthenticated attacker can bring down the entire `syscore` backend service. By repeatedly submitting code containing infinite loops, they will spawn Docker containers that consume resources and never exit. This will exhaust system memory, saturate the CPU, and completely block legitimate code execution requests, leading to a complete Denial of Service (DoS) for the application.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send an HTTP POST request to the `/api/execute` endpoint.
3. Provide the payload: `{"language": "python", "code": "while True: pass"}`.
4. Send this request multiple times concurrently.
5. Observe that the API stops responding to legitimate requests and the host's Docker daemon resources (memory/CPU) spike and are eventually exhausted.

✅ Recommended Remediation
Implement a strict execution timeout on the `wait_container` future. If the container execution exceeds the timeout threshold (e.g., 5-10 seconds), explicitly stop and kill the container, and return a "Timeout exceeded" error.

Example fix using `tokio::time::timeout`:
```rust
use std::time::Duration;

let timeout_duration = Duration::from_secs(5);
let wait_future = self.docker.wait_container::<String>(&id, None).next();

match tokio::time::timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
         tracing::warn!("[Job {}] Wait failed or container crashed", job_id);
    }
    Err(_) => {
         tracing::warn!("[Job {}] Execution timed out. Killing container.", job_id);
         let _ = self.docker.stop_container(&id, None).await;
         // Return an early error or handle the timeout condition
         return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- OWASP DoS (Denial of Service): https://owasp.org/www-community/attacks/Denial_of_Service
- Rust/Tokio timeouts: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
