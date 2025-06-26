#!/usr/bin/env python3
"""
Simple HTTP proxy server for HLS content with CORS support
"""

import http.server
import socketserver
import urllib.request
import urllib.parse
from urllib.error import HTTPError

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type, Authorization')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        # Check if this is an HLS request that should be proxied
        if self.path.startswith('/hls/') or self.path.startswith('/proxy/'):
            self.proxy_request()
        else:
            # Serve static files normally
            super().do_GET()

    def proxy_request(self):
        # Remove /proxy prefix if present
        path = self.path
        if path.startswith('/proxy/'):
            path = path[6:]  # Remove /proxy
        
        # Proxy to local transcoder service
        if path.startswith('/hls/'):
            target_url = f"http://localhost:8083{path}"
        elif path.startswith('/transcode/'):
            target_url = f"http://localhost:8083{path}"
        else:
            self.send_error(404, "Not Found")
            return

        try:
            # Forward the request
            if self.command == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length) if content_length > 0 else None
                req = urllib.request.Request(target_url, data=post_data, method='POST')
            else:
                req = urllib.request.Request(target_url)

            # Copy relevant headers
            for header in ['Range', 'Authorization']:
                if header in self.headers:
                    req.add_header(header, self.headers[header])

            with urllib.request.urlopen(req) as response:
                # Send response
                self.send_response(response.status)
                
                # Copy response headers
                for header, value in response.headers.items():
                    if header.lower() not in ['server', 'date']:
                        self.send_header(header, value)
                
                self.end_headers()
                
                # Copy response body
                self.wfile.write(response.read())

        except HTTPError as e:
            self.send_error(e.code, e.reason)
        except Exception as e:
            print(f"Proxy error: {e}")
            self.send_error(500, "Internal Server Error")

    def do_POST(self):
        if self.path.startswith('/proxy/'):
            self.proxy_request()
        else:
            self.send_error(404, "Not Found")

if __name__ == "__main__":
    PORT = 3000
    
    class TCPServer(socketserver.TCPServer):
        allow_reuse_address = True

    with TCPServer(("0.0.0.0", PORT), CORSHTTPRequestHandler) as httpd:
        print(f"🌐 Proxy server running on port {PORT}")
        print(f"📡 HLS streams available at: http://188.245.163.8:{PORT}/proxy/hls/")
        print(f"🎬 Enhanced player: http://188.245.163.8:{PORT}/live-player.html")
        httpd.serve_forever()