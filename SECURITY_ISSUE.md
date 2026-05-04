Title: 🛡️ CRITICAL Broken Auth: Hardcoded Fallback Secret in aether.rs upload_handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` function in `syscore/src/server/aether.rs` attempts to verify an authorization token using an environment variable `AETHER_UPLOAD_KEY`. However, if the environment variable is not set, it utilizes `unwrap_or_else` to fall back to a hardcoded, predictable string `"update_me_please"`. This hardcoded fallback acts as a backdoor, allowing any unauthorized party to authenticate and upload potentially malicious files. The vulnerability is located exactly on line 315.

🎯 Potential Impact
An unauthenticated attacker could upload malicious files or arbitrarily replace Aether software versions with compromised payloads, leading to a massive supply-chain attack when clients update.

🛠️ Steps to Reproduce
1. Start the backend server without `AETHER_UPLOAD_KEY` environment variable set.
2. Send an HTTP POST request to the upload endpoint with the header `Authorization: Bearer update_me_please`.
3. Include a multipart payload with `version`, `channel`, `file`, etc.
4. Observe that the server accepts and processes the upload with a `201 CREATED` status code.

✅ Recommended Remediation
Remove the `unwrap_or_else` fallback. Instead, the application should either fail to start if the `AETHER_UPLOAD_KEY` is missing from the environment, or the `upload_handler` should immediately reject uploads if the key is unset.

🔗 References
- OWASP Top 10 - Broken Access Control
- CWE-798: Use of Hard-coded Credentials
