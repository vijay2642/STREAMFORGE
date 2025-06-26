#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import urllib.parse
from urllib.error import HTTPError, URLError

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()
    
    def do_POST(self):
        self.proxy_request()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()
    
    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type, Authorization, Origin, X-Requested-With')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range')
        self.send_header('Access-Control-Max-Age', '86400')
    
    def proxy_request(self):
        # Forward to localhost:8083
        target_url = f"http://localhost:8083{self.path}"
        
        try:
            # Create request
            if self.command == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length) if content_length > 0 else None
                req = urllib.request.Request(target_url, data=post_data, method='POST')
            else:
                req = urllib.request.Request(target_url)
            
            # Copy headers
            for header in ['Range', 'Authorization', 'Content-Type']:
                if header in self.headers:
                    req.add_header(header, self.headers[header])
            
            # Make request
            with urllib.request.urlopen(req, timeout=10) as response:
                # Send response
                self.send_response(response.status)
                
                # Send CORS headers
                self.send_cors_headers()
                
                # Copy response headers (except server/date)
                for header, value in response.headers.items():
                    if header.lower() not in ['server', 'date', 'connection']:
                        self.send_header(header, value)
                
                # Special handling for M3U8 files
                if self.path.endswith('.m3u8'):
                    self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                    self.send_header('Pragma', 'no-cache')
                    self.send_header('Expires', '0')
                elif self.path.endswith('.ts'):
                    self.send_header('Cache-Control', 'public, max-age=10')
                
                self.end_headers()
                
                # Copy response body
                self.wfile.write(response.read())
                
        except (HTTPError, URLError) as e:
            print(f"Proxy error for {self.path}: {e}")
            self.send_response(503)
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(b'Service Unavailable')
        except Exception as e:
            print(f"Unexpected error for {self.path}: {e}")
            self.send_response(500)
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(b'Internal Server Error')

class TCPServer(socketserver.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    PORT = 8085
    
    with TCPServer(("0.0.0.0", PORT), ProxyHandler) as httpd:
        print(f"🔗 HLS Proxy running on port {PORT}")
        print(f"📡 Proxying to localhost:8083")
        print(f"🌐 Access streams at: http://188.245.163.8:{PORT}/hls/")
        httpd.serve_forever()