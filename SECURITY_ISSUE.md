Title: 🛡️ CRITICAL Hardcoded Secret: Weak default `AETHER_UPLOAD_KEY` bypasses authentication

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a hardcoded fallback secret used for authenticating requests. If the `AETHER_UPLOAD_KEY` environment variable is not set, the application defaults to using the weak static string `"update_me_please"`.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

This default value is hardcoded in the source code. Because this endpoint handles publishing new versions of Aether (uploading executable code), failing to provide a strong environment variable completely breaks authentication, leaving the endpoint open to anyone who reads the source code.

🎯 Potential Impact
An unauthenticated external attacker can upload malicious software updates (bundles, patches, and DMGs) via the `/api/v1/aether` endpoint. Clients relying on these updates will download and execute the attacker's payload, leading to widespread Remote Code Execution (RCE) on all client machines via Supply Chain compromise.

🛠️ Steps to Reproduce
1. Ensure the backend is running without `AETHER_UPLOAD_KEY` explicitly set in the environment.
2. Send a POST request to the `/api/v1/aether` endpoint.
3. Include the HTTP header `Authorization: Bearer update_me_please`.
4. Observe that the server accepts the upload and publishes the new version instead of returning a `401 Unauthorized`.

✅ Recommended Remediation
Remove the weak default fallback. The application should fail securely if critical secrets are missing. If `AETHER_UPLOAD_KEY` is not provided, the application should either fail to start, or the endpoint should consistently reject all requests.

```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .unwrap_or_else(|_| {
        tracing::error!("AETHER_UPLOAD_KEY is not set. Rejecting upload.");
        // Return an unguessable or empty string to guarantee failure,
        // or handle the Error response directly.
        "".to_string()
    });

if expected_key.is_empty() || auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```

🔗 References
- OWASP Hardcoded Secrets: https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
