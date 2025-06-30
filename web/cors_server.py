#!/usr/bin/env python3
import http.server
import socketserver
from http.server import SimpleHTTPRequestHandler
import sys
import time
import socket

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # Set proper MIME types for video files
        if self.path.endswith('.m3u8'):
            self.send_header('Content-Type', 'application/vnd.apple.mpegurl')
        elif self.path.endswith('.ts'):
            self.send_header('Content-Type', 'video/mp2t')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging to reduce noise
        pass

if __name__ == "__main__":
    PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000

    # Try to bind to the port with retries
    max_retries = 5
    for attempt in range(max_retries):
        try:
            # Allow socket reuse
            socketserver.TCPServer.allow_reuse_address = True
            with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
                print(f"Server running on port {PORT}")
                httpd.serve_forever()
                break
        except OSError as e:
            if e.errno == 98:  # Address already in use
                print(f"Port {PORT} in use, attempt {attempt + 1}/{max_retries}")
                if attempt < max_retries - 1:
                    time.sleep(2)
                    continue
                else:
                    print(f"Failed to bind to port {PORT} after {max_retries} attempts")
                    sys.exit(1)
            else:
                print(f"Error starting server: {e}")
                sys.exit(1)
