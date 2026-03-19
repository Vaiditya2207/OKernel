import http.server
import socketserver
import json
import os

PORT = 8080

class MockSysCoreHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/v1/aether/latest"):
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            data = {
                "version": "9.9.9",
                "description": "Mock Update for E2E Testing",
                "changelog": "- Added teleportation\n- Fixed gravity bugs",
                "release_date": "2026-03-19T20:00:00Z",
                "size": 1024,
                "bundle_filename": "Aether-bundle-9.9.9.tar.gz",
                "bundle_size": 1024,
                "channel": "stable"
            }
            self.wfile.write(json.dumps(data).encode())
            
        elif self.path.startswith("/api/v1/aether/download/bundle"):
            # Return a dummy tarball
            self.send_response(200)
            self.send_header("Content-type", "application/gzip")
            self.send_header("Content-Disposition", 'attachment; filename="Aether-bundle-9.9.9.tar.gz"')
            self.end_headers()
            # Minimal one-byte dummy file or empty
            self.wfile.write(b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00")
            
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/v1/aether/telemetry":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            print(f"[Telemetry] Received: {post_data.decode()}")
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    print(f"Starting Mock SysCore on port {PORT}...")
    with socketserver.TCPServer(("", PORT), MockSysCoreHandler) as httpd:
        print("MOCK SERVER LIVE. Point Aether to http://localhost:8080")
        httpd.serve_forever()
