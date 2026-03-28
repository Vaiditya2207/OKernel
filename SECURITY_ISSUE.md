Title: 🛡️ CRITICAL DoS: Unbounded Container Execution via Missing Timeout

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` orchestrates the running of untrusted user-submitted code (Python/C++) inside Docker containers. However, the wait condition for the container to exit lacks any timeout enforcement:

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because an attacker can submit code containing infinite loops (e.g., `while True: pass` in Python), the container will never exit. The Rust backend will `.await` indefinitely on this future. Over time, an attacker can submit multiple such requests, accumulating running containers and exhausting the server's CPU, memory, and async thread pool resources, leading to a complete Denial of Service (DoS) for the execution API.

🎯 Potential Impact
An unauthenticated or authenticated attacker can submit malicious code snippets that cause infinite loops, resulting in bounded threads/async workers and server resources being permanently consumed. This will quickly bring down the `syscore` backend service and prevent legitimate users from executing code.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a JSON POST request to the `/api/execute` endpoint (or via the frontend).
3. Provide the following payload:
```json
{
  "language": "python",
  "code": "while True:\n    pass\n"
}
```
4. Send the request. Observe that the request never returns a response.
5. Repeat step 4 multiple times.
6. Observe via `docker ps` or server resource monitoring that the CPU is maxed out and containers are accumulating indefinitely. The application will eventually become unresponsive to new requests.

✅ Recommended Remediation
Implement an explicit timeout for the container wait operation using `tokio::time::timeout`. If the container does not exit within an acceptable timeframe (e.g., 5-10 seconds), kill the container and return an error response to the user.

Example fix:
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
        tracing::error!("[Job {}] Execution timed out. Killing container.", job_id);
        // Implement logic to forcefully kill the container here
        let _ = self.docker.kill_container(&id, None).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- OWASP DoS (Denial of Service): https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
