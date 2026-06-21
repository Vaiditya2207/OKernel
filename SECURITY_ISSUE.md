Title: 🛡️ [CRITICAL] [Denial of Service]: Missing Timeout in Docker Container Wait Allows Resource Exhaustion

🚨 Severity
CRITICAL

💡 Description
The `syscore/src/docker/manager.rs` module contains a critical Denial of Service (DoS) vulnerability. Within the `execute` function, the `ContainerManager` runs untrusted user code in a newly created Docker container. On line 227:
```rust
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```
The execution relies on `.next().await` to indefinitely wait for the container to finish. Since the container execution limits specify memory and CPU limits but do not enforce a maximum execution time limit (timeout), an attacker could submit malicious code containing an infinite loop. This would cause the container to run forever, exhausting server resources over time, and keeping the asynchronous task running indefinitely.

🎯 Potential Impact
An attacker can perform a Denial of Service (DoS) attack. By repeatedly sending requests with infinite loops (e.g., `while True: pass` in Python), the attacker can exhaust the server's CPU, memory, and concurrency limits (as each execution spawns an indefinite async task). This will eventually cause the backend system to become unresponsive to legitimate user requests.

🛠️ Steps to Reproduce
1. Navigate to the code execution endpoint `/api/execute` (if publicly accessible or authenticated).
2. Input the following payload as Python code:
   ```python
   while True:
       pass
   ```
3. Observe the result: The API request hangs indefinitely and the backend task does not complete, tying up system resources. Over time, sending multiple such requests will degrade system performance or cause a crash.

✅ Recommended Remediation
Wrap the `wait_container` call with `tokio::time::timeout` to enforce a strict maximum execution time for the user's code. For example:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = timeout(Duration::from_secs(10), wait_future).await;

match wait_res {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out after 10 seconds", job_id);
        // Ensure cleanup_container logic follows
    }
}
```

🔗 References
- OWASP Top 10 - A04:2021-Insecure Design (Resource Exhaustion)
- https://owasp.org/www-community/attacks/Denial_of_Service