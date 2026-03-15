## 2024-05-18 - PathBuf::join Overwrite in Aether File Upload
Vulnerability Pattern: Arbitrary File Write via absolute path injection in `multipart.next_field().file_name()`.
Systemic Cause: The `upload_handler` blindly trusts the `filename` provided in the HTTP multipart request without sanitization. In Rust, `PathBuf::join` completely replaces the base path if the appended string is an absolute path, leading to out-of-bounds file writes.
Auditor Note: Always check usages of `PathBuf::join` with user-supplied strings, especially those extracted from multipart uploads, headers, or query parameters. Look for missing sanitization of path separators and absolute paths before path concatenation.

## 2025-01-28 - Unauthenticated WebSocket Endpoint
Vulnerability Pattern: Broken Auth / Access Control on WebSocket streaming endpoint.
Systemic Cause: WebSockets are inherently stateful and lack standard HTTP headers during the handshake in browser APIs. Developers often forget or skip implementing a custom authentication flow (e.g., ticket-based auth via query params or an initial auth payload) for WebSocket connections, leaving sensitive real-time data exposed to anyone who knows the subscription topic or ID.
Auditor Note: Always verify that WebSocket endpoints implement authentication and authorization checks, especially if they stream sensitive data or allow unauthenticated users to subscribe to specific channels or IDs.
