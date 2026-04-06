Title: 🛡️ CRITICAL DoS: Unbounded wait on untrusted execution in `/api/execute`

🚨 Severity
CRITICAL

💡 Description
The `/api/execute` endpoint orchestrates the execution of user-submitted code inside isolated Docker containers. In `syscore/src/docker/manager.rs`, the execution loop awaits `self.docker.wait_container::<String>(&id, None).next().await` to wait for the container to exit. However, this asynchronous operation does not employ any timeout mechanism (like `tokio::time::timeout`). Because this endpoint accepts untrusted user code without authentication or restriction, a malicious user can submit code containing an infinite loop. The container will run indefinitely, and the Rust async task will be permanently blocked awaiting the container's exit. A small number of concurrent requests executing infinite loops can exhaust server resources and open network connections, leading to a Denial of Service (DoS).

References:
- File: `syscore/src/docker/manager.rs`
- Relevant line context:
```rust
        // 6. Wait for execution to finish
        let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

🎯 Potential Impact
An attacker could cause a Denial of Service (DoS) by submitting multiple execution requests with code containing infinite loops, permanently consuming connection slots and memory as the server waits indefinitely for the containers to exit. The service would eventually become unresponsive to legitimate requests.

🛠️ Steps to Reproduce
1. Start the server and ensure the `/api/execute` endpoint is reachable.
2. Submit a request to the endpoint to execute a Python program containing `while True: pass`:
```bash
curl -X POST -H "Content-Type: application/json" -d '{"language":"python", "code":"while True: pass"}' http://localhost:8080/api/execute
```
3. Observe that the request never returns, and the backend server keeps running the container indefinitely.
4. Issue multiple similar requests to quickly exhaust the server's concurrent task capacity.

✅ Recommended Remediation
Wrap the `docker.wait_container` await call in a `tokio::time::timeout` to enforce a maximum execution duration (e.g., 10-30 seconds). If the timeout triggers, forcefully kill the container and return a timeout error to the user to prevent resource exhaustion.

Example:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(15), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        // Handle timeout: kill container and return error
        let _ = self.docker.stop_container(&id, None).await;
        // Optionally collect logs or just return an error
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- CWE-400: Uncontrolled Resource Consumption (https://cwe.mitre.org/data/definitions/400.html)
- Tokio Timeout Documentation (https://docs.rs/tokio/latest/tokio/time/fn.timeout.html)