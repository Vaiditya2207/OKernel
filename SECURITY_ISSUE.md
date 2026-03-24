# 🛡️ CRITICAL Logic Flaw: Denial of Service via Unbounded Docker Execution

🚨 Severity
CRITICAL

💡 Description
In `syscore/src/docker/manager.rs`, the `execute` method of `ContainerManager` spawns an ephemeral Docker container to run unauthenticated user-supplied code submitted to the `/api/execute` endpoint. The implementation calls `self.docker.wait_container::<String>(&id, None).next().await;` on line 203 without enforcing any timeout limit. As a result, if the user code contains an infinite loop or indefinitely blocking operation, the container will run forever, and the backend async task will hang permanently.

🎯 Potential Impact
An unauthenticated attacker can repeatedly submit code that enters an infinite loop, causing the backend to spawn numerous Docker containers that never terminate. This leads to complete exhaustion of host system resources (CPU, Memory, and Docker thread pool/file descriptors), resulting in a Denial of Service (DoS) for the entire application.

🛠️ Steps to Reproduce
1. Send a POST request to `/api/execute` with Python code designed to loop infinitely:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
2. Observe that the API request never receives a response.
3. Check the host system's running Docker containers (`docker ps`); the `okernel-job-<uuid>` container remains running indefinitely.
4. Repeat the request multiple times to exhaust server resources.

✅ Recommended Remediation
Implement a strict execution timeout on the container execution to limit its maximum lifespan. Wrap the `wait_container` await with `tokio::time::timeout`.

```rust
use tokio::time::{timeout, Duration};

// ...
let wait_future = self.docker.wait_container::<String>(&id, None).next();

match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(_) => {
        tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Execution timed out after 10 seconds", job_id);
        // Container cleanup happens below, but we should forcibly kill the container here if needed.
    }
}
```

🔗 References
- [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html)
- [OWASP Top 10: Security Misconfiguration](https://owasp.org/www-project-top-ten/2017/A6_2017-Security_Misconfiguration)
