Title: 🛡️ CRITICAL Hardcoded Secret/Broken Auth: Weak fallback for AETHER_UPLOAD_KEY in syscore

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` contains a Broken Authentication vulnerability due to a hardcoded fallback secret used for the API Key check.

On line 315 of `syscore/src/server/aether.rs`:
```rust
let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

The system is designed to authenticate file uploads by checking the `Authorization: Bearer <KEY>` header against the `AETHER_UPLOAD_KEY` environment variable. However, if the `AETHER_UPLOAD_KEY` is not set in the environment, `unwrap_or_else` defaults the expected key to `"update_me_please"`.

This introduces a severe security flaw: if an administrator forgets to configure `AETHER_UPLOAD_KEY`, the application fails open, allowing any attacker who knows or guesses the hardcoded default `"update_me_please"` to bypass authentication completely.

🎯 Potential Impact
An unauthenticated attacker can upload arbitrary files to the Aether storage by simply passing `Authorization: Bearer update_me_please`. Since this endpoint handles critical system updates (DMG bundles, patches), a malicious actor could upload compromised binaries (e.g., trojanized updates) to the system. If users or the updater clients download these patches, it could lead to widespread malware distribution and complete system compromise for anyone updating. Combined with the previously discovered Arbitrary File Write vulnerability, this could be used for Remote Code Execution on the host server.

🛠️ Steps to Reproduce
1. Start the `syscore` backend service *without* setting the `AETHER_UPLOAD_KEY` environment variable.
2. Send a POST request to the `/api/v1/aether` upload endpoint using a tool like `curl`:
```bash
curl -X POST http://localhost:3001/api/v1/aether \
  -H "Authorization: Bearer update_me_please" \
  -F "version=1.0.0-evil" \
  -F "file=@/path/to/any/file.dmg" \
  -F "description=Malicious Payload"
```
3. Observe that the server accepts the upload and responds with `201 Created` because the fallback authentication succeeds.

✅ Recommended Remediation
Fail securely when the environment variable is not set, rather than falling back to a default weak string.

1. Ideally, perform the configuration check at application startup (in `main.rs`) and refuse to boot if `AETHER_UPLOAD_KEY` is missing.
2. At the very least, change the `upload_handler` logic to return an error if the environment variable is not present:

```rust
// In syscore/src/server/aether.rs
let expected_key = std::env::var("AETHER_UPLOAD_KEY")
    .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Server misconfiguration: AETHER_UPLOAD_KEY not set".to_string()))?;
```

🔗 References
- OWASP Broken Authentication: https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication
- Hardcoded Credentials (CWE-798): https://cwe.mitre.org/data/definitions/798.html
