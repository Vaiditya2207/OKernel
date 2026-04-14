Title: 🛡️ CRITICAL Denial of Service (DoS): Unbounded wait in Docker container execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` orchestrates untrusted code execution within Docker containers. However, it fails to enforce a timeout when waiting for the container to exit:

```rust
// syscore/src/docker/manager.rs (lines 178-179)
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because `docker.wait_container` can block indefinitely, an attacker can submit an execution payload (e.g., via `/api/execute`) that contains an infinite loop or performs long-running blocking operations (like sleeping). This will cause the `execute` task to hang indefinitely, tying up system resources (both async task workers and Docker containers) leading to a Denial of Service.

🎯 Potential Impact
An unauthenticated attacker can continuously send requests with payloads designed to hang indefinitely (e.g., `while True: pass` in Python). This will exhaust the server's available file descriptors, memory, or async worker threads, completely bringing down the `syscore` API and preventing legitimate users from executing code.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a POST request to the `/api/execute` endpoint.
3. Provide the payload:
```json
{
  "language": "python",
  "code": "import time\nwhile True:\n    time.sleep(1)"
}
```
4. Send the request. Notice that the HTTP request hangs and never returns a response.
5. Send multiple such requests concurrently to observe resource exhaustion.

✅ Recommended Remediation
Wrap the `docker.wait_container` await operation with a strict timeout using `tokio::time::timeout`. If the timeout is reached, proactively kill/remove the container and return a timeout error to the user.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out", job_id);
        // Clean up the container explicitly if it times out
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html