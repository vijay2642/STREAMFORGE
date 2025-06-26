#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import urllib.parse
import urllib.error
import json
import os

class StreamForgeProxyHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers to all responses
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type, Authorization, Origin, X-Requested-With')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self.path.startswith('/api/'):
            self.proxy_to_transcoder()
        elif self.path.startswith('/hls/'):
            self.proxy_to_transcoder()
        else:
            # Serve static files
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api/'):
            self.proxy_to_transcoder()
        else:
            self.send_error(404)

    def proxy_to_transcoder(self):
        # Remove /api prefix if present, keep /hls as is
        if self.path.startswith('/api/'):
            target_path = self.path[4:]  # Remove /api
        else:
            target_path = self.path
            
        target_url = f"http://localhost:8083{target_path}"
        
        try:
            # Handle POST data
            post_data = None
            if self.command == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    post_data = self.rfile.read(content_length)

            # Create request
            req = urllib.request.Request(target_url, data=post_data, method=self.command)
            
            # Copy headers
            for header in ['Range', 'Authorization', 'Content-Type']:
                if header in self.headers:
                    req.add_header(header, self.headers[header])

            # Make request
            with urllib.request.urlopen(req, timeout=10) as response:
                # Send response
                self.send_response(response.status)
                
                # Copy response headers
                for header, value in response.headers.items():
                    if header.lower() not in ['server', 'date', 'connection']:
                        self.send_header(header, value)
                
                # Special caching for HLS files
                if self.path.endswith('.m3u8'):
                    self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                    self.send_header('Pragma', 'no-cache')
                    self.send_header('Expires', '0')
                elif self.path.endswith('.ts'):
                    self.send_header('Cache-Control', 'public, max-age=10')
                
                self.end_headers()
                
                # Stream response body
                while True:
                    chunk = response.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    
        except urllib.error.HTTPError as e:
            print(f"HTTP Error {e.code} for {target_url}: {e.reason}")
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(f"Upstream error: {e.reason}".encode())
            
        except urllib.error.URLError as e:
            print(f"URL Error for {target_url}: {e.reason}")
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b"Service temporarily unavailable")
            
        except Exception as e:
            print(f"Proxy error for {target_url}: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"Internal server error")

class TCPServer(socketserver.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    PORT = 3000
    
    # Change to web directory to serve static files
    os.chdir('/root/STREAMFORGE/web')
    
    with TCPServer(("0.0.0.0", PORT), StreamForgeProxyHandler) as httpd:
        print(f"🌐 StreamForge Web Server + Proxy running on port {PORT}")
        print(f"📁 Serving static files from: /root/STREAMFORGE/web")
        print(f"🔗 Proxying /api/* and /hls/* to localhost:8083")
        print(f"🎬 Access players at:")
        print(f"  • Enhanced: http://188.245.163.8:{PORT}/live-player.html")
        print(f"  • Original: http://188.245.163.8:{PORT}/index.html")
        print(f"  • Test: http://188.245.163.8:{PORT}/test-player.html")
        httpd.serve_forever()