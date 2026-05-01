Title: 🛡️ CRITICAL Broken Auth: Weak default fallback for AETHER_UPLOAD_KEY allows unauthorized uploads

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Auth vulnerability due to a weak default fallback for the `AETHER_UPLOAD_KEY` environment variable. When the `AETHER_UPLOAD_KEY` environment variable is not set, the application uses `unwrap_or_else` to fall back to the hardcoded string `"update_me_please"`.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

Because environment variables representing secrets may inadvertently be omitted during deployment, an attacker can use the known default key `"update_me_please"` to bypass authentication on the critical upload endpoint (`/api/v1/aether`).

🎯 Potential Impact
An unauthenticated attacker can upload malicious software updates, bundles, or patches to the Aether release storage, compromising the integrity of the update system. This could lead to a supply chain attack where malicious updates are distributed to clients, resulting in widespread Remote Code Execution (RCE) on user machines.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting the `AETHER_UPLOAD_KEY` environment variable.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Provide the default authentication header: `Authorization: Bearer update_me_please`.
4. Include text form fields for `version` (e.g., `1.0.0`), `description`, and `changelog`.
5. Include a file upload field named `file` containing the malicious payload.
6. Send the request.
7. Observe that the server accepts the request and publishes the uploaded file.

✅ Recommended Remediation
Remove the weak default fallback for `AETHER_UPLOAD_KEY`. The application should reject the request securely if the environment variable is not provided, enforcing the requirement for a strong, explicit secret.

Example fix:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server configuration error".to_string()))?;
```

🔗 References
- OWASP Broken Access Control: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
- CWE-1188: Initialization of a Resource with an Insecure Default: https://cwe.mitre.org/data/definitions/1188.html
