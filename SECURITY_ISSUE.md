Title: 🛡️ CRITICAL DoS: Unbounded wait on untrusted code execution

🚨 Severity
CRITICAL

💡 Description
The `execute` method in `syscore/src/docker/manager.rs` contains a Denial of Service (DoS) vulnerability due to the lack of a timeout when waiting for a Docker container to finish executing user-submitted code.
In the execution flow, the backend spawns a bespoke container to run the untrusted code and waits for it to exit:

```rust
// syscore/src/docker/manager.rs (around line 170)
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;

if let Some(Ok(res)) = wait_res {
    tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
} else {
    tracing::warn!("[Job {}] Wait failed or container crashed specifically", job_id);
}
```

Because there is no explicit timeout applied to `self.docker.wait_container(...).next().await`, an attacker can submit code containing an infinite loop (e.g., `while True: pass` in Python). The container will run indefinitely, and the Rust asynchronous task handling the execution will be blocked forever waiting for the container to exit.

🎯 Potential Impact
An attacker can intentionally submit code that never terminates (like infinite loops or sleep commands). This will cause the backend to wait indefinitely, consuming system resources (such as active Docker containers, memory limits, and backend asynchronous tasks). An influx of such requests can lead to severe resource exhaustion, eventually causing a full Denial of Service (DoS) and crashing or stalling the entire `syscore` backend service.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Construct a request to the code execution endpoint (e.g., `/api/execute`).
3. Provide a payload that executes an infinite loop in the target language (e.g., `{"lang": "Python", "code": "while True: pass"}`).
4. Send the request.
5. Observe that the API endpoint never returns a response, and the corresponding Docker container created for this execution remains running indefinitely on the host machine.
6. Repeat step 4 multiple times to exhaust backend resources.

✅ Recommended Remediation
Implement an explicit timeout mechanism using `tokio::time::timeout` when awaiting the completion of the container. If the timeout expires, the system should forcefully terminate the container and return a timeout error to the user.

Example fix:
```rust
use tokio::time::{timeout, Duration};

let wait_future = self.docker.wait_container::<String>(&id, None).next();

// Wait up to 10 seconds for the container to exit
match timeout(Duration::from_secs(10), wait_future).await {
    Ok(Some(Ok(res))) => {
        tracing::debug!("[Job {}] Container exited with code {}", job_id, res.status_code);
    }
    Ok(Some(Err(e))) => {
        tracing::warn!("[Job {}] Error waiting for container: {}", job_id, e);
    }
    Ok(None) => {
        tracing::warn!("[Job {}] Container wait stream ended unexpectedly", job_id);
    }
    Err(_) => {
        tracing::error!("[Job {}] Container execution timed out!", job_id);
        // Ensure cleanup happens immediately
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
}
```

🔗 References
- OWASP Denial of Service: https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio `timeout` documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html
