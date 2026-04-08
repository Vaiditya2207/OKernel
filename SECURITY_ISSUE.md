Title: 🛡️ CRITICAL DoS: Missing Timeout on Untrusted Code Execution

🚨 Severity
CRITICAL

💡 Description
In `syscore/src/docker/manager.rs`, the `execute` method spawns a Docker container to run untrusted code submitted via the `/api/execute` endpoint. The process waits for the execution to finish using `self.docker.wait_container::<String>(&id, None).next().await;` without any explicit timeout. If a user submits malicious code that enters an infinite loop, the container will run indefinitely. Because there is no timeout wrapping the await call, the request handler will hang indefinitely, leading to resource exhaustion (CPU, memory, and concurrent connection limits) and potentially a complete Denial of Service (DoS) for the application.

🎯 Potential Impact
An unauthenticated attacker can repeatedly submit code with infinite loops (e.g., `while True: pass` in Python), causing the backend to spawn containers that never terminate. This will exhaust system resources and hang async executor threads, taking the entire server offline.

🛠️ Steps to Reproduce
1. Start the server and ensure Docker execution is functional.
2. Send a POST request to `/api/execute` with a payload containing an infinite loop:
   ```json
   {
       "language": "python",
       "code": "while True: pass"
   }
   ```
3. Observe that the request never returns a response.
4. Check running Docker containers and notice that the container remains running indefinitely, consuming resources.

✅ Recommended Remediation
Wrap the `self.docker.wait_container` call in a `tokio::time::timeout` block to enforce a strict upper bound on execution time (e.g., 5-10 seconds). If the timeout elapses, forcefully kill and remove the container, then return a timeout error to the user.

🔗 References
- [OWASP Top 10 - A04:2021-Insecure Design (Resource Exhaustion)](https://owasp.org/Top10/A04_2021-Insecure_Design/)
- [Tokio Timeout Documentation](https://docs.rs/tokio/latest/tokio/time/fn.timeout.html)
