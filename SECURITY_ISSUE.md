Title: 🛡️ CRITICAL DoS: Missing timeout in Docker container execution

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` orchestrates the execution of untrusted user code by spawning a bespoke Docker container. The backend service waits for the container to exit using `self.docker.wait_container::<String>(&id, None).next().await`.

However, there is no timeout applied to this wait operation. If an attacker submits a payload that runs indefinitely (e.g., an infinite loop `while True: pass` in Python, or `while(1);` in C++), the container will never exit, and the `wait_container` future will pend indefinitely. Because each code execution request occupies a task, multiple requests containing infinite loops will exhaust the server's asynchronous task workers and system resources (due to running containers), leading to a Denial of Service (DoS) vulnerability.

File: `syscore/src/docker/manager.rs`
Lines:
```rust
        // 6. Wait for execution to finish
        let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

🎯 Potential Impact
An unauthenticated attacker can repeatedly submit code execution requests (`/api/execute`) containing infinite loops. This will cause the backend to spawn Docker containers that run indefinitely and never get cleaned up, quickly exhausting all server resources (CPU, Memory, and network connections) and making the system completely unresponsive.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to the `/api/execute` endpoint with a payload containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Observe that the API request hangs and never returns a response.
4. Repeat step 2 multiple times.
5. Check running Docker containers (`docker ps`) on the host system. You will observe multiple containers stuck running indefinitely.

✅ Recommended Remediation
Implement an explicit timeout for the container wait operation using `tokio::time::timeout`. If the timeout is reached, the server should forcibly kill the container and return an error to the user indicating that the execution timed out.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

// ...

// 6. Wait for execution to finish with a timeout
let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
        Some(Ok(res))
    },
    Ok(Some(Err(e))) => {
        tracing::warn!("[Job {}] Container wait error: {}", job_id, e);
        None
    },
    Ok(None) => None,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out, forcibly removing container...", job_id);
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
