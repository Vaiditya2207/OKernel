Title: 🛡️ CRITICAL Logic Flaw: Missing Execution Timeout Allows Denial of Service via Infinite Loops

🚨 Severity
CRITICAL

💡 Description
The unauthenticated `/api/execute` endpoint invokes containerized execution of user code via `ContainerManager::execute` in `syscore/src/docker/manager.rs`. However, there is a missing timeout on the execution of the user's code.

In `syscore/src/docker/manager.rs`, around line 170:
```rust
        // 6. Wait for execution to finish
        let wait_res = self.docker.wait_container::<String>(&id, None).next().await;
```

The system uses `self.docker.wait_container(...).next().await;` which waits indefinitely for the container to finish. Because untrusted user code runs inside these containers (e.g., Python/C++ code), an attacker can supply code with an infinite loop. This forces the server thread to block indefinitely, consuming server resources (e.g. Docker container instances, memory, CPU, and tokio tasks) until the host crashes or becomes unresponsive.

🎯 Potential Impact
An unauthenticated attacker can submit multiple execution requests with infinite loops, exhausting system resources (Docker containers, available CPU/memory limits) and causing a complete Denial of Service (DoS) for the entire application.

🛠️ Steps to Reproduce
1. Start the backend service.
2. Send a POST request to `/api/execute` with malicious Python code that loops forever:
   ```json
   {
       "lang": "Python",
       "code": "while True: pass"
   }
   ```
3. Observe that the server hangs waiting for the container to exit, and the container runs indefinitely.
4. Sending multiple such requests will exhaust server resources.

✅ Recommended Remediation
Implement an explicit timeout for container execution using `tokio::time::timeout`.

Example:
```rust
        // 6. Wait for execution to finish with a strict timeout (e.g., 5 seconds)
        let timeout_duration = std::time::Duration::from_secs(5);
        let wait_future = self.docker.wait_container::<String>(&id, None).next();

        let wait_res = match tokio::time::timeout(timeout_duration, wait_future).await {
            Ok(res) => res,
            Err(_) => {
                tracing::warn!("[Job {}] Container execution timed out. Forcing termination.", job_id);
                // Optionally kill the container here
                None
            }
        };
```

🔗 References
- [OWASP Top 10: Vulnerable and Outdated Components (CWE-400: Uncontrolled Resource Consumption)](https://cwe.mitre.org/data/definitions/400.html)
