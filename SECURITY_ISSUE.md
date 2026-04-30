Title: 🛡️ CRITICAL Broken Auth: Hardcoded Weak Fallback API Key in upload_handler

🚨 Severity
CRITICAL

💡 Description
The `upload_handler` in `syscore/src/server/aether.rs` relies on an environment variable `AETHER_UPLOAD_KEY` for authenticating uploads. However, it uses `unwrap_or_else` to fallback to a weak default key `"update_me_please"` if the environment variable is missing. This bypasses secure authentication if the deployment environment does not properly set this variable.

🎯 Potential Impact
An unauthenticated attacker can use the default key `"update_me_please"` to bypass the authorization check and arbitrarily upload malicious Aether versions, bundles, and patches to the server. This leads to complete compromise of the update delivery mechanism.

🛠️ Steps to Reproduce
1. Ensure the `AETHER_UPLOAD_KEY` environment variable is not set on the server.
2. Send a POST request to the upload endpoint with `Authorization: Bearer update_me_please`.
3. Include valid multipart form data with a dummy `file`, `version`, etc.
4. Observe that the server accepts the payload and returns `201 CREATED`.

✅ Recommended Remediation
Remove the `unwrap_or_else` fallback. The application should fail securely if the `AETHER_UPLOAD_KEY` environment variable is not provided.

🔗 References
- OWASP Top 10: Broken Access Control
- CWE-798: Use of Hard-coded Credentials
