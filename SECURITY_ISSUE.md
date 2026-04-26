Title: 🛡️ CRITICAL Denial of Service: Unbounded Wait in Docker Container Execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` launches a docker container to execute user-submitted code. However, it waits for the container to exit using an unbounded `.await` on `wait_container`.

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

If a user submits code containing an infinite loop (e.g., `while True: pass` in Python), the container will run indefinitely. The backend thread will hang forever waiting for the container to finish. This missing execution timeout allows malicious or poorly written code to tie up backend resources, leading to resource exhaustion.

🎯 Potential Impact
An attacker can perform a Denial of Service (DoS) attack by submitting multiple requests with code that enters an infinite loop. This will exhaust server threads, memory, and Docker container limits, rendering the code execution service unavailable for other users. Complete exhaustion could crash the `syscore` backend.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send an execution payload to the `/api/execute` endpoint via a POST request with an infinite loop.
   Payload example: `{"language": "python", "code": "while True: pass"}`
3. Observe that the API request never completes and the container runs indefinitely.
4. Send multiple such requests to exhaust server capabilities and observe the Denial of Service.

✅ Recommended Remediation
Implement a strict execution timeout. Wrap the `wait_container` future with `tokio::time::timeout` so that if the container execution exceeds a specified duration (e.g., 5-10 seconds), the wait is cancelled and the container is forcefully killed.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::error!("[Job {}] Container execution timed out", job_id);
        // Ensure container is killed and cleaned up here
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP DoS Vulnerabilities: https://owasp.org/www-community/attacks/Denial_of_Service
