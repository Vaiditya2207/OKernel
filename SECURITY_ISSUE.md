Title: 🛡️ CRITICAL Broken Auth: Unauthenticated WebSocket endpoint for log streaming

🚨 Severity
CRITICAL

💡 Description
The WebSocket handler `websocket_handler` in `syscore/src/server/websocket.rs` completely lacks authentication and authorization checks. When a client connects to the `/ws/stream` endpoint, they can send a `subscribe:<job_id>` message to start receiving live logs and tracing data from any active container.
There is no verification that the connecting user owns the `job_id` or is authenticated at all.
```rust
// syscore/src/server/websocket.rs
// No auth middleware is applied to the route, and the handler blindly accepts the subscription:
if text.starts_with("subscribe:") {
    let job_id = text.trim_start_matches("subscribe:").trim();
    tracing::info!("WS subscribing to job: {}", job_id);

    if let Some(mut rx) = manager.subscribe(job_id).await {
        // Streams data to any connected client
```

🎯 Potential Impact
An unauthenticated attacker can connect to the WebSocket endpoint and subscribe to any active `job_id`. Since job IDs might be predictable or leaked (or the attacker could simply brute-force active UUIDs if they have enough throughput, though UUIDv4 makes this harder, the endpoint still exposes data without auth). If an attacker obtains a valid `job_id`, they can stream sensitive execution logs, source code snippets (via trace events), and memory contents of other users' executing code, leading to severe Data Leakage and privacy violations.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service.
2. Submit a valid code execution request to `/api/execute` to generate a valid `job_id` and start a container.
3. Using a generic WebSocket client (e.g., `wscat` or a browser console), connect to `ws://localhost:3001/ws/stream` without any authentication headers or tokens.
4. Send the message `subscribe:<job_id>` using the valid `job_id` obtained in step 2.
5. Observe that the server begins streaming the container's execution logs and trace events to your unauthenticated WebSocket client.

✅ Recommended Remediation
Implement authentication and authorization for the WebSocket endpoint.
1. Require a valid authentication token (e.g., JWT) to be passed during the WebSocket handshake (via query parameters or a subprotocol, since standard HTTP headers are limited in browser WS APIs), or require the first message sent over the socket to be an authentication payload.
2. Validate the token and ensure the user is authorized to access the requested `job_id`. The `ContainerManager` or the job state should track which user owns which `job_id`.

🔗 References
- OWASP Broken Access Control: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
- Axum WebSocket Authentication Examples: https://github.com/tokio-rs/axum/tree/main/examples
