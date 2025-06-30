#!/usr/bin/env python3
"""
Simple API proxy for StreamForge Quality Tester
Provides CORS-enabled access to transcoder API
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.parse
import json
import sys

class APIProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Enable CORS
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        
        # Route API requests
        if self.path.startswith('/api/'):
            # Remove /api prefix and forward to transcoder service
            transcoder_path = self.path[4:]  # Remove '/api'
            transcoder_url = f'http://localhost:8083{transcoder_path}'
            
            try:
                with urllib.request.urlopen(transcoder_url) as response:
                    data = response.read()
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(data)
            except Exception as e:
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                error_response = json.dumps({'error': str(e), 'success': False})
                self.wfile.write(error_response.encode())
        
        elif self.path.startswith('/hls/'):
            # Forward HLS requests to HLS server
            hls_url = f'http://localhost:8085{self.path}'
            
            try:
                with urllib.request.urlopen(hls_url) as response:
                    data = response.read()
                    # Determine content type
                    if self.path.endswith('.m3u8'):
                        content_type = 'application/vnd.apple.mpegurl'
                    elif self.path.endswith('.ts'):
                        content_type = 'video/mp2t'
                    else:
                        content_type = 'application/octet-stream'
                    
                    self.send_header('Content-Type', content_type)
                    self.end_headers()
                    self.wfile.write(data)
            except Exception as e:
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}'.encode())
        
        else:
            # Serve static files
            if self.path == '/' or self.path == '/index.html':
                file_path = '/root/STREAMFORGE/web/player.html'
            elif self.path == '/quality-test' or self.path == '/quality-test.html':
                file_path = '/root/STREAMFORGE/web/quality-test.html'
            elif self.path == '/player' or self.path == '/player.html':
                file_path = '/root/STREAMFORGE/web/player.html'
            else:
                file_path = f'/root/STREAMFORGE/web{self.path}'
            
            try:
                with open(file_path, 'rb') as f:
                    content = f.read()
                    
                    # Determine content type
                    if file_path.endswith('.html'):
                        content_type = 'text/html'
                    elif file_path.endswith('.js'):
                        content_type = 'application/javascript'
                    elif file_path.endswith('.css'):
                        content_type = 'text/css'
                    else:
                        content_type = 'application/octet-stream'
                    
                    self.send_header('Content-Type', content_type)
                    self.end_headers()
                    self.wfile.write(content)
            except FileNotFoundError:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b'File not found')

    def do_OPTIONS(self):
        # Handle preflight requests
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def log_message(self, format, *args):
        # Reduce log verbosity
        pass

if __name__ == '__main__':
    port = 3001
    server = HTTPServer(('0.0.0.0', port), APIProxyHandler)
    print(f"🔧 API Proxy running on http://localhost:{port}")
    print(f"🎬 Quality Tester: http://localhost:{port}")
    print(f"📡 Proxying to transcoder: http://localhost:8083")
    print(f"📺 Proxying to HLS server: http://localhost:8085")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n✅ Server stopped")
        sys.exit(0)