Title: 🛡️ [HIGH] Denial of Service: Missing Timeout on Docker Container Execution

🚨 Severity
HIGH

💡 Description
In `syscore/src/docker/manager.rs`, the `execute` method is responsible for running untrusted user code in ephemeral Docker containers. The backend spawns the container and waits for the execution to finish using `docker.wait_container`. However, there is no timeout mechanism applied to this wait operation:

```rust
// syscore/src/docker/manager.rs:96
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because `docker.wait_container` waits indefinitely, an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python or `while(1) {}` in C++). The container will never exit naturally, causing the Rust `async` task handling the execution request to hang forever while holding resources. If an attacker submits multiple requests, they can exhaust the server's thread pool, available RAM, and CPU resources, causing a Denial of Service (DoS) for all legitimate users.

🎯 Potential Impact
An unauthenticated or authenticated user could submit a script with an infinite loop. This will cause the `execute` task to hang indefinitely, tying up system resources (CPU, Memory, and connection limits) on the host machine. By sending multiple requests concurrently, an attacker can easily exhaust the server's limits, rendering the SysCore execution engine unresponsive (Denial of Service).

🛠️ Steps to Reproduce
1. Start the SysCore backend server (`cargo run` in `syscore/`).
2. Submit a valid execution request to the `/api/execute` endpoint containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass"
   }
   ```
3. Observe that the HTTP request never receives a response.
4. Check the host machine's resources or Docker containers (`docker ps`); the container (`okernel-job-XXX`) will be running indefinitely.
5. Send multiple similar requests to overwhelm the backend, leading to complete resource exhaustion.

✅ Recommended Remediation
Implement a strict execution timeout (e.g., 5-10 seconds) on the container wait operation. Since `tokio` is being used, `tokio::time::timeout` can wrap the `.next().await` call. If the timeout elapses before the container finishes, the execution should be forcibly aborted, the container destroyed, and an appropriate error returned to the client.

Example fix:
```rust
use tokio::time::{timeout, Duration};

// ...
let wait_future = self.docker.wait_container::<String>(&id, None).next();

// Wait for a maximum of 10 seconds
match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    },
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed", job_id);
    },
    Err(_) => {
        // Timeout occurred!
        tracing::warn!("[Job {}] Execution timed out. Forcibly terminating.", job_id);
        // Container cleanup happens below in the existing flow
    }
}
```

🔗 References
- OWASP DoS (Denial of Service): https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeouts: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html