Title: 🛡️ [CRITICAL] [Denial of Service]: Unbounded wait_container enables container resource exhaustion

🚨 Severity
CRITICAL

💡 Description
The `syscore/src/docker/manager.rs` module manages the lifecycle of unauthenticated, ephemeral Docker containers meant to execute user-submitted code snippets. At line 227 within the `execute` method, the system waits for the spawned container to finish its task by indefinitely awaiting `self.docker.wait_container`.

```rust
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because this async operation lacks a timeout context (such as `tokio::time::timeout`), any malicious payload that intentionally hangs or spins in an infinite loop (e.g., `while True: pass` in Python) will cause the Rust execution task to yield and await indefinitely. Eventually, an attacker can dispatch multiple requests, each allocating a new Docker container and retaining resources up to the host limits (CPUs, Mem, Network). Since the container is manually cleaned up *after* `wait_container` finishes, infinite execution ensures the container is never destroyed.

🎯 Potential Impact
An unauthenticated attacker can trivially exhaust all available host resources (RAM, CPU cycles, concurrent tasks) by sending simple infinite-loop payloads to the `/api/execute` endpoint. This will crash or severely degrade the backend infrastructure for legitimate users, representing a critical Denial of Service (DoS) vulnerability.

🛠️ Steps to Reproduce
1. Start the system's `syscore` backend service.
2. Formulate a JSON POST request to the `/api/execute` route with the payload:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass"
   }
   ```
3. Send this request multiple times.
4. Observe that the endpoint hangs indefinitely, and checking host resource usage (`docker ps`, `htop`) reveals stranded orphaned containers consuming resources relentlessly without any automatic cleanup or task timeout on the server.

✅ Recommended Remediation
Wrap the `docker.wait_container` await operation with a strict timeout (e.g., `tokio::time::timeout`) to ensure the execution yields an error on expiration. If a timeout happens, the system should catch the error and forcefully terminate the container so host resources are freed.

```rust
use tokio::time::{timeout, Duration};

// Wait for execution to finish (maximum 10 seconds)
let timeout_duration = Duration::from_secs(10);
let wait_future = self.docker.wait_container::<String>(&id, None).next();

let wait_res = match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
        Some(Ok(res))
    },
    Ok(Some(Err(e))) => {
        tracing::error!("[Job {}] Container wait error: {}", job_id, e);
        Some(Err(e))
    },
    Ok(None) => None,
    Err(_) => {
        tracing::warn!("[Job {}] Container execution timed out!", job_id);
        // Container will be killed and cleaned up in step 8
        None
    }
};
```

🔗 References
- [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html)
- [OWASP: Denial of Service](https://owasp.org/www-community/attacks/Denial_of_Service)
- [Tokio time timeout documentation](https://docs.rs/tokio/latest/tokio/time/fn.timeout.html)