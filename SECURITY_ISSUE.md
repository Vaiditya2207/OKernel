Title: 🛡️ [CRITICAL] Denial of Service: Infinite Execution Loop via Missing Timeout in Docker Manager

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` lacks an execution timeout when waiting for a Docker container to complete its job. Specifically, the line `let wait_res = self.docker.wait_container::<String>(&id, None).next().await;` awaits the container exit without any upper bound on execution time.
Because users can submit arbitrary code via the `/api/execute` endpoint (which calls `manager.execute`), a malicious user can submit code with an infinite loop (e.g., `while True: pass` in Python). This causes the spawned container to run indefinitely, and the `syscore` backend will wait infinitely for it to exit, tying up async tasks and consuming system resources continuously until the host crashes or memory/CPU is completely exhausted.

🎯 Potential Impact
An unauthenticated attacker can submit a few infinite loop scripts to the `/api/execute` endpoint, completely exhausting server resources (CPU and memory) and locking up asynchronous worker threads in the Rust backend. This leads to a total Denial of Service (DoS) for the OKernel platform, preventing any other users from executing code or accessing platform features.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a POST request to the `/api/execute` endpoint with an infinite loop payload:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass\n"
   }
   ```
3. Send the request. Notice that the request hangs indefinitely.
4. Check the backend server resources and notice that a new Docker container `okernel-job-<uuid>` is spawned and consumes 100% of its allocated CPU.
5. Repeat step 2 multiple times to exhaust all available server resources.

✅ Recommended Remediation
Implement a strict timeout wrapper around the `wait_container` call using `tokio::time::timeout`. If the container does not exit within the allowed time (e.g., 10 seconds), forcefully kill and remove the container to free up resources and return an error to the user.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let timeout_duration = Duration::from_secs(10); // 10 second timeout

match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed", job_id);
    }
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out after {} seconds", job_id, timeout_duration.as_secs());
        // Force kill the container
        let _ = self.docker.stop_container(&id, None).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- OWASP Unrestricted Resource Consumption: https://owasp.org/API-Security/editions/2023/en/0x11-t04-unrestricted-resource-consumption/
