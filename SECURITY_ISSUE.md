# 🛡️ CRITICAL Broken Auth: Hardcoded Secret Fallback for Aether Uploads

## 🚨 Severity
CRITICAL

## 💡 Description
The `/api/v1/aether` upload endpoint in `syscore` contains a severe vulnerability where missing configuration falls back to a hardcoded secret.

In `syscore/src/server/aether.rs`, the `upload_handler` attempts to retrieve the `AETHER_UPLOAD_KEY` environment variable for authenticating automated uploads (e.g., from CI/CD pipelines). However, if the environment variable is missing or not set, it explicitly falls back to a weak, hardcoded default value (`"update_me_please"`).

**File Location:** `syscore/src/server/aether.rs`
**Code Snippet:**
```rust
    let expected_key = std::env::var("AETHER_UPLOAD_KEY").unwrap_or_else(|_| "update_me_please".to_string());
```

This logic flaw allows unauthorized users to publish arbitrary files or malicious binaries under any version identifier if the server operator forgets to configure `AETHER_UPLOAD_KEY`. Rather than failing securely (denying access), the system defaults to an insecure state.

## 🎯 Potential Impact
An unauthenticated attacker could publish malicious Aether binaries or patches by exploiting this hardcoded fallback. If users are retrieving updates through these channels, it could lead to severe supply chain attacks. This completely compromises the integrity of the published software artifacts.

## 🛠️ Steps to Reproduce
1. Start the `syscore` backend *without* the `AETHER_UPLOAD_KEY` environment variable set.
2. Send a `POST /api/v1/aether` request with a multipart form payload (including `version`, `file`, etc.).
3. Set the `Authorization` header to `Bearer update_me_please`.
4. Observe that the server returns a `201 Created` and successfully stores the upload in the `storage/aether` directory.

## ✅ Recommended Remediation
Remove the hardcoded fallback entirely. The application should fail securely if the environment variable is not present. Ideally, the `expected_key` should be checked during the startup sequence of `syscore`, failing to boot if a valid configuration is missing. Alternatively, at the very least, reject the request if the environment variable is not set.

Suggested fix in `syscore/src/server/aether.rs`:
```rust
    let expected_key = match std::env::var("AETHER_UPLOAD_KEY") {
        Ok(key) if !key.is_empty() => key,
        _ => return Err((StatusCode::INTERNAL_SERVER_ERROR, "Upload key not configured".to_string())),
    };
```

## 🔗 References
* [OWASP Top 10 A07:2021 – Identification and Authentication Failures](https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/)
* [OWASP Top 10 A05:2021 – Security Misconfiguration](https://owasp.org/Top10/A05_2021-Security_Misconfiguration/)
* [CWE-798: Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)