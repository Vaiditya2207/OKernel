Title: 🛡️ CRITICAL DoS: Unbounded wait on container execution allows resource exhaustion

🚨 Severity
CRITICAL

💡 Description
The `execute` function in `syscore/src/docker/manager.rs` contains a critical Denial of Service (DoS) vulnerability. When orchestrating untrusted user code via Docker containers, it starts the container and waits for it to exit using `self.docker.wait_container::<String>(&id, None).next().await;` (around line 203). However, this wait operation lacks a timeout.

An attacker can submit an infinite loop (e.g., `while True: pass` in Python) via the unauthenticated `/api/execute` endpoint. Since there's no execution timeout on the `wait_container` call, the asynchronous task will await indefinitely. By submitting multiple such requests, an attacker can rapidly exhaust server resources (memory, async worker threads, and open Docker containers), leading to a complete Denial of Service for the backend.

🎯 Potential Impact
An unauthenticated attacker can bring down the `syscore` backend service by submitting a handful of execution requests containing infinite loops. This exhausts server resources and halts all execution processing, causing a complete Denial of Service (DoS) for the platform.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a JSON POST request to the unauthenticated `/api/execute` endpoint.
3. Provide the payload: `{"language": "python", "code": "while True: pass"}`.
4. Send the request multiple times in parallel.
5. Observe that the API requests never complete, and backend resources (such as memory and Docker containers) grow indefinitely, eventually crashing the service.

✅ Recommended Remediation
Implement explicit timeouts when waiting for untrusted code execution to finish. Wrap the `wait_container` call with `tokio::time::timeout`.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

// Wait for execution to finish with a strict 10-second timeout
let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(10), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Execution timed out", job_id);
        // Force cleanup and return early
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- CWE-400: Uncontrolled Resource Consumption: https://cwe.mitre.org/data/definitions/400.html
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html