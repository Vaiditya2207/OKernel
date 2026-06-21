Title: 🛡️ CRITICAL DoS: Unbounded Wait on Untrusted Docker Containers

🚨 Severity
CRITICAL

💡 Description
The `syscore/src/docker/manager.rs` execution logic contains a Denial of Service (DoS) vulnerability in the `ContainerManager::execute` function. The code relies on an unbounded wait for a newly spawned Docker container to complete its execution:

```rust
// syscore/src/docker/manager.rs
let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

Because this endpoint (`/api/execute`) accepts unauthenticated, untrusted code (such as Python or C++) to be run inside the container, an attacker can submit code containing an infinite loop or long sleep (e.g., `while True: pass` in Python). The backend server will indefinitely await the container's completion without any timeout. Since each execution may tie up a `tokio` task and Docker resources (CPU/Memory/Process table limits), an attacker can easily exhaust system resources, rendering the backend completely unresponsive.

🎯 Potential Impact
An unauthenticated user can continuously send malicious code payloads containing infinite loops to the `/api/execute` endpoint. This will spawn Docker containers that never exit and backend tasks that never complete. Ultimately, this exhausts server resources (such as memory, CPU, or available file descriptors/tasks), leading to a complete Denial of Service (DoS) for all users relying on the backend.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Send a POST request to `/api/execute` with an infinite loop payload. For example, using `curl`:
```bash
curl -X POST http://localhost:3001/api/execute \
     -H "Content-Type: application/json" \
     -d '{"language": "python", "code": "while True:\n    pass"}'
```
3. Observe that the request never returns.
4. Send multiple similar requests concurrently.
5. Observe that the backend system resources are continuously consumed and the service eventually becomes unresponsive to legitimate requests.

✅ Recommended Remediation
Always use explicit timeouts when orchestrating untrusted code or container runs. Wrap the `wait_container` future with `tokio::time::timeout` to enforce a maximum execution duration (e.g., 5 seconds). If the timeout is reached, force kill and remove the container.

Example fix:
```rust
use std::time::Duration;
use tokio::time::timeout;

let wait_future = self.docker.wait_container::<String>(&id, None).next();
let wait_res = match timeout(Duration::from_secs(5), wait_future).await {
    Ok(res) => res,
    Err(_) => {
        tracing::warn!("[Job {}] Container execution timed out", job_id);
        // Ensure cleanup_container is called immediately to kill it
        let _ = self.cleanup_container(&id).await;
        return Err("Execution timed out".to_string());
    }
};
```

🔗 References
- OWASP DoS Vulnerabilities: https://owasp.org/www-community/attacks/Denial_of_Service
- Tokio Timeout Documentation: https://docs.rs/tokio/latest/tokio/time/fn.timeout.html