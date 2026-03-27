Title: 🛡️ CRITICAL Denial of Service: Unbounded container execution in /api/execute

🚨 Severity
CRITICAL

💡 Description
The `ContainerManager::execute` function in `syscore/src/docker/manager.rs` orchestrates untrusted code execution submitted via the `/api/execute` endpoint. Currently, it waits for the Docker container to exit using `self.docker.wait_container::<String>(&id, None).next().await;` without any explicit timeout.

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because there is no timeout enforcement on the `wait_container` call, a malicious user can submit code containing an infinite loop (e.g., `while True: pass` in Python or `while(1) {}` in C++). This will cause the container to run indefinitely, consuming the allocated CPU and memory resources (256MB RAM, 1 CPU). Multiple such requests will exhaust server resources, leading to a complete Denial of Service (DoS) for the OKernel platform.

🎯 Potential Impact
An unauthenticated attacker can submit multiple payloads with infinite loops to the `/api/execute` endpoint. Since each payload spins up a container that never exits and holds resources indefinitely, the server's CPU, memory, and concurrent task limits will quickly be exhausted, rendering the OKernel backend unresponsive to legitimate users.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to the `/api/execute` endpoint with an infinite loop payload:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass"
   }
   ```
3. Observe that the API request hangs indefinitely and never returns.
4. Check the Docker daemon (`docker ps`); the spawned container (`okernel-job-<uuid>`) will be running and consuming CPU.
5. Send multiple such requests to completely exhaust server resources.

✅ Recommended Remediation
Enforce a strict timeout on the container execution wait using `tokio::time::timeout`. If the timeout expires, the system should forcefully kill/remove the container and return an error to the user indicating a timeout occurred.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();

match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(Some(Err(e))) => {
        tracing::warn!("[Job {}] Container wait error: {}", job_id, e);
    }
    Ok(None) => {
        tracing::warn!("[Job {}] Wait stream ended unexpectedly", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out! Force killing container.", job_id);
        // Container removal logic already runs in cleanup, but ensure it force-kills
    }
}
```

🔗 References
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html
- Rust `tokio::time::timeout` documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html