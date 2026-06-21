Title: 🛡️ [CRITICAL] [Denial of Service]: Unbounded wait in docker container execution leads to DoS

🚨 Severity
CRITICAL

💡 Description
In `syscore/src/docker/manager.rs`, the `execute` method spawns an ephemeral Docker container to run user-submitted code (via Python or C++). However, on line 227:

```rust
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

The system waits indefinitely for the container to finish execution. There is no timeout enforced around this `.await` call. If a user submits malicious code containing an infinite loop (e.g., `while True: pass` in Python), the container will run forever. Because `host_config` restricts network and memory but does NOT restrict execution time, the async task inside `execute_handler` will hang indefinitely.

Over time, an attacker can submit multiple requests with infinite loops, exhausting server resources (memory, CPU, and available Docker tasks/threads), leading to a complete Denial of Service (DoS) for the entire application.

🎯 Potential Impact
An attacker can completely halt the code execution service and crash or severely degrade the backend server by continuously submitting code with infinite loops, exhausting underlying system and Docker resources.

🛠️ Steps to Reproduce
1. Navigate to the code execution endpoint (e.g., `/api/execute`).
2. Input the following Python payload:
   ```python
   while True:
       pass
   ```
3. Observe that the request never returns, and the Docker container running the code remains active indefinitely, tying up system resources.

✅ Recommended Remediation
Implement a strict execution timeout using `tokio::time::timeout` around the `wait_container` call. If the execution exceeds the allowed time (e.g., 5 seconds), forcefully kill and remove the container.

```rust
use std::time::Duration;
use tokio::time::timeout;

// ...
let wait_future = self.docker.wait_container::<String>(&id, None).next();
match timeout(Duration::from_secs(5), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out. Force killing container.", job_id);
        // Clean up immediately
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- OWASP DoS (Denial of Service): https://owasp.org/www-community/attacks/Denial_of_Service
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html