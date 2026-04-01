Title: 🛡️ CRITICAL Denial of Service: Unbounded Execution of Untrusted Code via `/api/execute`

🚨 Severity
CRITICAL

💡 Description
The `syscore/src/docker/manager.rs` module manages the execution of untrusted user-submitted code in Docker containers. In the `execute` method, the system initiates a Docker container and waits for its execution to complete:

```rust
// syscore/src/docker/manager.rs (lines ~227)
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

This `await` call lacks any explicit timeout mechanism. Since the user can submit arbitrary code via the `/api/execute` endpoint (handled in `syscore/src/server/routes.rs`), an attacker can submit code that runs indefinitely, such as an infinite loop (`while True: pass` in Python).

Because the system blocks forever waiting on this container to finish, it leaves the container running continuously. This consumes memory, CPU, and keeps a connection and tokio task open indefinitely. Repeated submissions will quickly exhaust server resources, leading to a complete Denial of Service (DoS) for the entire application.

🎯 Potential Impact
An unauthenticated attacker can trivially exhaust the server's compute resources (memory, CPU, worker threads, and Docker container limits) by submitting multiple execution payloads that loop infinitely. This will render the `/api/execute` endpoint, and potentially the entire `syscore` backend service, unresponsive to legitimate users.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send an HTTP POST request to the `/api/execute` endpoint with an infinite loop payload:
   ```json
   {
       "language": "python",
       "code": "while True:\n    pass\n"
   }
   ```
3. Observe that the HTTP request never returns a response.
4. Check the host system's running Docker containers (`docker ps`). Notice the `okernel-job-<uuid>` container remains running indefinitely, utilizing 100% of its allocated CPU.
5. Send several more identical requests. The host's resources will eventually be completely exhausted.

✅ Recommended Remediation
Implement an explicit overarching timeout for the container execution wait step using `tokio::time::timeout`. If the execution exceeds a reasonable timeframe (e.g., 5 or 10 seconds), forcefully kill and remove the container to reclaim resources.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

let wait_future = self.docker.wait_container::<String>(&id, None).next();

if let Ok(Some(Ok(res))) = timeout(Duration::from_secs(10), wait_future).await {
    tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
} else {
    tracing::warn!("[Job {}] Container execution timed out or failed to wait. Forcing cleanup.", job_id);
    let _ = self.docker.stop_container(&id, Some(bollard::container::StopContainerOptions { t: 0 })).await;
}
```

🔗 References
- OWASP Top 10 - Security Misconfiguration (Resource Exhaustion): https://owasp.org/www-project-top-ten/
- Tokio Timeouts: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html