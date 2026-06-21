Title: 🛡️ [CRITICAL] Denial of Service: Missing timeout in /api/execute container runs

🚨 Severity
CRITICAL

💡 Description
The `ContainerManager::execute` function in `syscore/src/docker/manager.rs` relies on `docker.wait_container::<String>(&id, None).next().await` (at line 227) without a timeout wrapper. The `/api/execute` endpoint processes unauthenticated requests to run user-submitted code in bespoke Docker containers. By submitting a script with an infinite loop, an attacker can cause the `wait_container` future to never resolve, leaking the container instance, network connections, and host memory/CPU. This allows a malicious user to quickly exhaust server resources and achieve a Denial of Service (DoS) against the system.

🎯 Potential Impact
An unauthenticated remote attacker could send multiple payloads containing infinite loops to the code execution endpoint, exhausting CPU, memory, and container instances on the server. This would result in a complete Denial of Service for the application and potentially crash the host running the containers.

🛠️ Steps to Reproduce
1. Send an HTTP POST request to `/api/execute` with an infinite loop payload (e.g., Python: `while True: pass`).
2. Observe that the server spawns a container that never exits, and the backend HTTP response eventually times out.
3. Check the host's Docker processes using `docker ps`; the spawned container is still consuming resources.
4. Send enough similar requests to exhaust system limits, taking down the service.

✅ Recommended Remediation
Wrap the `docker.wait_container` future with `tokio::time::timeout` to enforce a strict upper bound on execution time (e.g., 5-10 seconds) for user-provided scripts.

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
        tracing::warn!("[Job {}] Container execution timed out", job_id);
        // Ensure container is forcefully killed here if it timed out
        let _ = self.docker.kill_container(&id, None).await;
    }
}
```

🔗 References
- OWASP: Unrestricted Resource Consumption (https://owasp.org/www-community/vulnerabilities/Denial_of_Service)
- Rust `tokio::time::timeout` (https://docs.rs/tokio/latest/tokio/time/fn.timeout.html)
