Title: 🛡️ CRITICAL DoS: Unbounded execution of untrusted code in Docker manager

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` spawns a Docker container to run untrusted, user-submitted code (Python or C++) without enforcing an execution timeout. It awaits completion using `self.docker.wait_container::<String>(&id, None).next().await`. Because no timeout is provided, if the user submits code containing an infinite loop or an intentionally long-running operation, the container will run indefinitely.

```rust
// syscore/src/docker/manager.rs
// 6. Wait for execution to finish
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

While a memory constraint (256 MB) and CPU share limit are configured via `HostConfig`, the lack of a wall-clock timeout allows an attacker to exhaust connection pools, memory, and CPU cycles over time by submitting multiple non-terminating jobs. This prevents legitimate users from executing code and can bring down the entire code execution service.

🎯 Potential Impact
A Denial of Service (DoS) attack where an attacker can submit multiple infinite loop scripts to permanently consume server resources (e.g., container slots, memory, and CPU limits) rendering the `/api/execute` endpoint and potentially the entire host unresponsive or permanently degraded until manual intervention occurs.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a request to the `/api/execute` endpoint specifying the `Python` language.
3. Submit the following code payload: `while True: pass`
4. Send the request multiple times.
5. Observe that the API endpoint becomes permanently blocked waiting for the containers to finish, as `wait_container` never returns. Use `docker ps` to verify that multiple `okernel-job-*` containers are running endlessly.

✅ Recommended Remediation
Wrap the `wait_container` operation in an asynchronous timeout such as `tokio::time::timeout`. If the timeout expires before the container finishes, forcefully kill and remove the container.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

// 6. Wait for execution to finish with a timeout
let timeout_duration = Duration::from_secs(10); // Example 10 second timeout
let wait_future = self.docker.wait_container::<String>(&id, None).next();

match timeout(timeout_duration, wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(Some(Err(e))) => {
        tracing::warn!("[Job {}] Wait failed: {}", job_id, e);
    }
    Ok(None) => {
        tracing::warn!("[Job {}] Stream ended unexpectedly", job_id);
    }
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out after {:?}", job_id, timeout_duration);
        // Container must be forcefully stopped
        let _ = self.docker.stop_container(&id, None).await;
    }
}
```

🔗 References
- Docker Engine API `wait`: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerWait
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html