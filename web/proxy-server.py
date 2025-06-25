#!/usr/bin/env python3
import http.server
import socketserver
import urllib.request
import urllib.parse
import json
from urllib.error import HTTPError

class CORSProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/proxy/'):
            # Extract the real URL from the proxy path
            real_path = self.path[7:]  # Remove '/proxy/'
            if not real_path.startswith('/'):
                real_path = '/' + real_path
            real_url = f"http://localhost:8083{real_path}"
            
            try:
                # Fetch the content from the transcoder
                with urllib.request.urlopen(real_url) as response:
                    content = response.read()
                    content_type = response.headers.get('content-type', 'text/plain')
                
                # Send response with CORS headers
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type')
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                
            except HTTPError as e:
                self.send_response(e.code)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                if e.code == 404:
                    error_response = json.dumps({"error": "Not found", "success": False})
                    self.wfile.write(error_response.encode('utf-8'))
            except Exception as e:
                print(f"Proxy error: {e}, URL: {real_url}")
                self.send_response(500)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = json.dumps({"error": str(e), "success": False})
                self.wfile.write(error_response.encode('utf-8'))
                
        else:
            # Serve static files normally
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/proxy/'):
            # Handle POST requests to transcoder API
            real_path = self.path[7:]  # Remove '/proxy/'
            if not real_path.startswith('/'):
                real_path = '/' + real_path
            real_url = f"http://localhost:8083{real_path}"
            
            try:
                # Get POST data if any
                content_length = int(self.headers.get('content-length', 0))
                post_data = self.rfile.read(content_length) if content_length > 0 else None
                
                # Create request
                req = urllib.request.Request(real_url, data=post_data, method='POST')
                if post_data:
                    req.add_header('Content-Type', 'application/json')
                
                # Fetch the response
                with urllib.request.urlopen(req) as response:
                    content = response.read()
                    content_type = response.headers.get('content-type', 'application/json')
                
                # Send response with CORS headers
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type')
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                
            except HTTPError as e:
                self.send_response(e.code)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = json.dumps({"error": f"HTTP {e.code}", "success": False})
                self.wfile.write(error_response.encode('utf-8'))
            except Exception as e:
                print(f"Proxy POST error: {e}, URL: {real_url}")
                self.send_response(500)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = json.dumps({"error": str(e), "success": False})
                self.wfile.write(error_response.encode('utf-8'))
        else:
            self.send_response(405)
            self.end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Range, Content-Type')
        self.end_headers()

if __name__ == "__main__":
    PORT = 8082
    with socketserver.TCPServer(("", PORT), CORSProxyHandler) as httpd:
        print(f"🌐 CORS Proxy Server running on http://localhost:{PORT}")
        print(f"📺 Demo ready at: http://localhost:{PORT}")
        print(f"🎯 Proxying transcoder API and HLS files with full CORS support")
        httpd.serve_forever() 