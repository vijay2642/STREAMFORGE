#!/usr/bin/env python3

import http.server
import socketserver
import os
import sys
import subprocess
import json
import time
from datetime import datetime
from urllib.parse import urlparse, parse_qs

class AdminProxyHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        # Handle admin API requests
        if self.path.startswith('/api/admin/'):
            self.handle_admin_api()
        else:
            super().do_GET()

    def do_POST(self):
        # Handle admin API POST requests
        if self.path.startswith('/api/admin/'):
            self.handle_admin_api()
        else:
            self.send_error(404)

    def handle_admin_api(self):
        """Handle admin API requests inline"""
        try:
            parsed_path = urlparse(self.path)
            path = parsed_path.path

            if path == '/api/admin/disk-usage':
                response = self.get_disk_usage()
            elif path == '/api/admin/streams':
                if self.command == 'POST':
                    content_length = int(self.headers.get('Content-Length', 0))
                    post_data = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
                    data = json.loads(post_data) if post_data else {}
                    response = self.handle_stream_control(data)
                else:
                    response = self.get_streams_info()
            elif path == '/api/admin/files':
                response = self.get_files_info()
            elif path == '/api/admin/cleanup':
                if self.command == 'POST':
                    content_length = int(self.headers.get('Content-Length', 0))
                    post_data = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
                    data = json.loads(post_data) if post_data else {}
                    response = self.handle_cleanup(data)
                else:
                    response = {'status': 'error', 'message': 'POST method required'}
            else:
                response = {'status': 'error', 'message': 'API endpoint not found'}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        except Exception as e:
            error_response = {'status': 'error', 'message': str(e)}
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(error_response).encode())

    def get_disk_usage(self):
        """Get disk usage information"""
        usage_info = {}
        
        # Get HLS directory usage
        hls_dir = "/tmp/hls_shared"
        if os.path.exists(hls_dir):
            result = subprocess.run(['du', '-sh', hls_dir], capture_output=True, text=True)
            if result.returncode == 0:
                usage_info['hls_usage'] = result.stdout.split()[0]
            else:
                usage_info['hls_usage'] = '0B'
        else:
            usage_info['hls_usage'] = '0B'
        
        return {'status': 'success', 'data': usage_info}

    def get_streams_info(self):
        """Get stream information"""
        try:
            # Check HLS files for active streams
            active_streams = 0
            hls_dir = "/tmp/hls_shared"
            
            if os.path.exists(hls_dir):
                for stream in ['stream1', 'stream2']:
                    stream_dir = os.path.join(hls_dir, stream)
                    if os.path.exists(stream_dir):
                        files = os.listdir(stream_dir)
                        ts_files = [f for f in files if f.endswith('.ts')]
                        if ts_files:
                            # Check if any file is recent (within last 60 seconds)
                            recent_files = []
                            for ts_file in ts_files[-5:]:  # Check last 5 files
                                file_path = os.path.join(stream_dir, ts_file)
                                file_age = time.time() - os.path.getmtime(file_path)
                                if file_age < 60:  # Less than 60 seconds old
                                    recent_files.append(ts_file)
                            
                            if recent_files:
                                active_streams += 1

            # Real viewer count would need nginx-rtmp stats parsing or analytics integration
            # For now, show 0 since we don't have real viewer tracking
            total_viewers = 0
            
            return {
                'status': 'success',
                'data': {
                    'active_streams': active_streams,
                    'total_viewers': total_viewers,
                    'note': 'Viewer tracking requires analytics integration'
                }
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Failed to get stream info: {str(e)}'
            }

    def get_files_info(self):
        """Get file information"""
        file_info = []
        
        # HLS files
        hls_dir = "/tmp/hls_shared"
        if os.path.exists(hls_dir):
            for stream in os.listdir(hls_dir):
                stream_path = os.path.join(hls_dir, stream)
                if os.path.isdir(stream_path):
                    files = os.listdir(stream_path)
                    ts_files = [f for f in files if f.endswith('.ts')]
                    m3u8_files = [f for f in files if f.endswith('.m3u8')]
                    
                    if ts_files or m3u8_files:
                        # Get total size
                        total_size = sum(os.path.getsize(os.path.join(stream_path, f)) 
                                       for f in files)
                        
                        # Get last modified
                        last_modified = max(os.path.getmtime(os.path.join(stream_path, f)) 
                                          for f in files) if files else 0
                        
                        file_info.append({
                            'path': stream_path,
                            'type': 'hls',
                            'stream_name': stream,
                            'file_count': len(files),
                            'ts_count': len(ts_files),
                            'm3u8_count': len(m3u8_files),
                            'total_size': total_size,
                            'last_modified': datetime.fromtimestamp(last_modified).isoformat()
                        })
        
        return {
            'status': 'success',
            'data': {
                'files': file_info
            }
        }

    def handle_stream_control(self, data):
        """Handle stream control"""
        action = data.get('action')
        stream_name = data.get('stream')
        
        if action == 'stop':
            # Drop publishers using nginx control
            try:
                cmd = ['curl', '-s', f'http://localhost:8080/control/drop/publisher?app=live&name={stream_name}']
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                return {
                    'status': 'success',
                    'message': f'Stream {stream_name} stopped',
                    'action': action,
                    'stream': stream_name
                }
            except Exception as e:
                return {
                    'status': 'warning',
                    'message': f'Could not stop {stream_name}: {str(e)}',
                    'action': action,
                    'stream': stream_name
                }
        
        elif action in ['start', 'restart']:
            return {
                'status': 'info',
                'message': f'Stream {stream_name} ready for RTMP publishing',
                'action': action,
                'stream': stream_name,
                'rtmp_url': f'rtmp://188.245.163.8:1935/live/{stream_name}'
            }
        
        return {'status': 'error', 'message': f'Unknown action: {action}'}

    def handle_cleanup(self, data):
        """Handle cleanup operations"""
        cleanup_type = data.get('type', 'hls')
        timeframe = data.get('timeframe', 'hour')
        
        script_path = "/root/STREAMFORGE/scripts/cleanup-system.sh"
        
        try:
            result = subprocess.run([script_path, cleanup_type, timeframe], 
                                  capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                return {
                    'status': 'success',
                    'message': f'Cleanup completed: {cleanup_type} ({timeframe})',
                    'output': result.stdout
                }
            else:
                return {
                    'status': 'error',
                    'message': f'Cleanup failed: {result.stderr}',
                    'output': result.stdout
                }
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Cleanup operation failed: {str(e)}'
            }

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
DIRECTORY = "/root/STREAMFORGE/web"

os.chdir(DIRECTORY)
with socketserver.TCPServer(("", PORT), AdminProxyHandler) as httpd:
    print(f"Serving at port {PORT} with admin API integrated")
    httpd.serve_forever()