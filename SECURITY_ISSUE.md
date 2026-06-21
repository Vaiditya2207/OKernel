Title: 🛡️ CRITICAL Hardcoded Secret: Weak default fallback for AETHER_UPLOAD_KEY

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Hardcoded Secret vulnerability due to the use of a weak, static default fallback value when the `AETHER_UPLOAD_KEY` environment variable is missing.

```rust
// syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());

if auth_header != Some(&expected_key) {
    return Err((StatusCode::UNAUTHORIZED, "Invalid or missing API Key".to_string()));
}
```

If the deployment environment fails to explicitly set the `AETHER_UPLOAD_KEY` variable, the server will silently fallback to expecting the hardcoded `"update_me_please"` token. Attackers can trivially exploit this known default string to bypass authentication.

🎯 Potential Impact
An unauthenticated external attacker can upload malicious Aether binaries (DMG, bundles, or patches) to the OKernel infrastructure. This leads to a Supply Chain Attack where end-users of Aether Terminal downloading updates will receive the attacker's compromised binary, resulting in widespread Remote Code Execution (RCE) on client machines.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service in an environment where `AETHER_UPLOAD_KEY` is not defined.
2. Construct a multipart POST request to the `/api/v1/aether` upload endpoint.
3. Provide the hardcoded default authentication header: `Authorization: Bearer update_me_please`.
4. Include necessary form fields for a new version (e.g., `version`, `file` containing a malicious binary).
5. Send the request.
6. Observe that the server responds with a `201 CREATED` status and successfully processes the upload.

✅ Recommended Remediation
Remove the `unwrap_or_else` fallback. The application should fail securely if critical configuration variables are missing. Consider enforcing this validation at startup to ensure the server does not boot without proper secrets configured.

Example fix:
```rust
// At startup / configuration load time:
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .expect("CRITICAL: AETHER_UPLOAD_KEY environment variable is missing!");

// In the handler, use the globally loaded secret without fallback
```

🔗 References
- OWASP Hardcoded Passwords/Keys: https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password
- CWE-798: Use of Hard-coded Credentials: https://cwe.mitre.org/data/definitions/798.html
