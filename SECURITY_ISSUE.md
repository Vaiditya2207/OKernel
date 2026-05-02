Title: 🛡️ CRITICAL Broken Auth: Weak default fallback for AETHER_UPLOAD_KEY enables unauthorized uploads

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` implements authentication by checking the `Authorization` header against the `AETHER_UPLOAD_KEY` environment variable. However, if this environment variable is not set, it falls back to a weak, hardcoded default value (`"update_me_please"`) using `unwrap_or_else`.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

This ensures the endpoint is always accessible via a known default credential if the system administrator forgets to properly configure the environment variable, entirely defeating the authentication mechanism.

🎯 Potential Impact
An unauthenticated attacker can use the known default key `"update_me_please"` to bypass authentication and upload malicious payloads to the Aether release endpoint. Given that this endpoint handles file uploads, an attacker could exploit this to upload malware or overwrite files on the host machine.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service without setting the `AETHER_UPLOAD_KEY` environment variable.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Include the default authorization header: `Authorization: Bearer update_me_please`.
4. Send the request with valid form data.
5. Observe that the server accepts the upload with a `201 Created` response, successfully bypassing the intended authentication.

✅ Recommended Remediation
Remove the `unwrap_or_else` fallback. The endpoint should securely fail and reject all uploads if the key is not explicitly configured.

Example fix:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server upload key not configured".to_string()))?;
```

🔗 References
- OWASP Broken Authentication: https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
