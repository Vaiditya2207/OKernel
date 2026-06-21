Title: 🛡️ CRITICAL Logic Flaw: Denial of Service via Unbounded Docker Wait

🚨 Severity
CRITICAL

💡 Description
A Denial of Service (DoS) vulnerability exists in `syscore/src/docker/manager.rs` within the `ContainerManager::execute` function. This function creates an ephemeral Docker container to execute user-submitted code from the `/api/execute` endpoint. The execution logic waits for the container to exit using `docker.wait_container::<String>(&id, None).next().await;` without applying any explicit timeout mechanisms.

```rust
// syscore/src/docker/manager.rs (Lines 226-231)
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;

if let Some(Ok(res)) = wait_res {
     tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
} else {
// ...
```

If an attacker submits a payload containing an infinite loop (e.g., `while True: pass` in Python), the container will run indefinitely. Because there is no timeout on `wait_container`, the backend thread handling the request will block forever. Repeated requests with similar payloads will rapidly exhaust the server's thread pool and connection limits, rendering the application unavailable.

🎯 Potential Impact
An unauthenticated attacker can submit malicious code to the `/api/execute` endpoint. By providing code that never terminates, the attacker can force the backend server threads to hang indefinitely. Once all available threads or resources are exhausted, the server will stop responding to legitimate requests, resulting in a complete Denial of Service.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a POST request to the `/api/execute` endpoint.
3. Include a JSON payload with an infinite loop:
   ```json
   {
     "language": "python",
     "code": "while True:\n    pass\n"
   }
   ```
4. Send the request. Notice that the request does not return.
5. Send several similar requests concurrently.
6. Observe that the server becomes unresponsive to other API endpoints because threads are stuck waiting for containers that will never exit.

✅ Recommended Remediation
Wrap the `docker.wait_container` call with an explicit timeout using `tokio::time::timeout`. If the timeout expires before the container finishes, forcibly kill and remove the container to free up resources.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let timeout_duration = Duration::from_secs(10); // e.g., 10 seconds timeout

match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out, killing container...", job_id);
        // Force remove or stop container here
        let _ = self.docker.stop_container(&id, None).await;
    }
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Denial of Service Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html
