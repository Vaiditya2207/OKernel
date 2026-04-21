Title: 🛡️ CRITICAL Denial of Service: Unbounded Wait on Container Execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` contains a Denial of Service (DoS) vulnerability due to an unbounded asynchronous wait.
When executing untrusted code via the `execute` method, the code waits indefinitely for the container to finish executing:

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

If a user submits code containing an infinite loop (e.g., `while True: pass` in Python), the container will run indefinitely. Because there is no explicit timeout wrapping the `wait_container` future, the backend service will hang on this request forever, tying up asynchronous workers and resources. An attacker could submit multiple such requests to quickly exhaust the server's execution slots, leading to a complete Denial of Service.

🎯 Potential Impact
An unauthenticated or authenticated attacker can submit malicious payloads containing infinite loops to the code execution endpoint. This causes the Docker containers to run indefinitely and the backend API to block on those requests forever. Multiple such submissions will exhaust system resources (CPU, Memory, and asynchronous task slots), leading to a complete Denial of Service for all users attempting to execute code.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service with Docker enabled.
2. Send a POST request to the `/api/v1/execute` endpoint (or equivalent code execution endpoint) with a Python payload containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass"
   }
   ```
3. Observe that the API request never completes and hangs indefinitely.
4. Check the running Docker containers (`docker ps`) and observe that the execution container continues running.
5. Send multiple such requests to completely exhaust the server's concurrent execution capacity.

✅ Recommended Remediation
Implement an explicit timeout using `tokio::time::timeout` when awaiting the container execution. Additionally, ensure the container is forcefully killed and cleaned up if the timeout is reached.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

// 6. Wait for execution to finish with a timeout
let wait_future = self.docker.wait_container::<String>(&id, None).next();
let timeout_duration = Duration::from_secs(10); // Example 10-second timeout

match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out. Forcefully killing container.", job_id);
        // Ensure the container is forcefully stopped/killed before cleaning up
        let _ = self.docker.kill_container::<String>(&id, None).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
