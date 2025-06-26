#!/usr/bin/env python3
"""
Thunderbird Streaming Platform - Admin API
Provides backend functionality for the admin dashboard
"""

import os
import json
import subprocess
import time
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

class AdminAPIHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.api_routes = {
            '/api/admin/disk-usage': self.handle_disk_usage,
            '/api/admin/cleanup': self.handle_cleanup,
            '/api/admin/streams': self.handle_streams,
            '/api/admin/logs': self.handle_logs,
            '/api/admin/stats': self.handle_stats,
            '/api/admin/files': self.handle_files,
        }
        super().__init__(*args, **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        
        if path in self.api_routes:
            try:
                response = self.api_routes[path](parsed_path.query)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_error_response(500, str(e))
        else:
            self.send_error_response(404, "API endpoint not found")

    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        
        # Read POST data
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
        
        try:
            data = json.loads(post_data)
        except json.JSONDecodeError:
            data = {}
        
        if path in self.api_routes:
            try:
                response = self.api_routes[path](data)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_error_response(500, str(e))
        else:
            self.send_error_response(404, "API endpoint not found")

    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def send_error_response(self, code, message):
        """Send error response"""
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        error_response = {'error': message, 'code': code}
        self.wfile.write(json.dumps(error_response).encode())

    def handle_disk_usage(self, query_or_data):
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
        
        # Get recordings directory usage
        recordings_dir = "/tmp/recordings"
        if os.path.exists(recordings_dir):
            result = subprocess.run(['du', '-sh', recordings_dir], capture_output=True, text=True)
            if result.returncode == 0:
                usage_info['recordings_usage'] = result.stdout.split()[0]
            else:
                usage_info['recordings_usage'] = '0B'
        else:
            usage_info['recordings_usage'] = '0B'
        
        # Get total /tmp usage
        result = subprocess.run(['df', '-h', '/tmp'], capture_output=True, text=True)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                fields = lines[1].split()
                usage_info['total_space'] = fields[1]
                usage_info['used_space'] = fields[2]
                usage_info['available_space'] = fields[3]
                usage_info['usage_percentage'] = fields[4]
        
        return {'status': 'success', 'data': usage_info}

    def handle_cleanup(self, query_or_data):
        """Handle cleanup operations"""
        if isinstance(query_or_data, dict):
            # POST request
            cleanup_type = query_or_data.get('type', 'hls')
            timeframe = query_or_data.get('timeframe', 'hour')
        else:
            # GET request
            params = parse_qs(query_or_data)
            cleanup_type = params.get('type', ['hls'])[0]
            timeframe = params.get('timeframe', ['hour'])[0]
        
        script_path = "/root/STREAMFORGE/scripts/cleanup-system.sh"
        
        try:
            # Run cleanup script
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
        except subprocess.TimeoutExpired:
            return {
                'status': 'error',
                'message': 'Cleanup operation timed out'
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Cleanup operation failed: {str(e)}'
            }

    def handle_streams(self, query_or_data):
        """Handle stream management"""
        # Handle POST requests for stream control
        if isinstance(query_or_data, dict):
            action = query_or_data.get('action')
            stream_name = query_or_data.get('stream')
            
            if action and stream_name:
                return self.control_stream(stream_name, action)
        
        try:
            # Get nginx-rtmp stats
            result = subprocess.run(['curl', '-s', 'http://localhost:8080/stat'], 
                                  capture_output=True, text=True, timeout=10)
            
            active_streams = 0
            total_viewers = 0
            
            if result.returncode == 0 and result.stdout:
                # Simple parsing - count occurrences of stream names
                if 'stream1' in result.stdout:
                    active_streams += 1
                if 'stream2' in result.stdout:
                    active_streams += 1
                
                # Estimate viewers (this would be more sophisticated in production)
                total_viewers = active_streams * 1247
            
            # Check HLS files to see which streams are actually active
            hls_streams = []
            hls_dir = "/tmp/hls_shared"
            if os.path.exists(hls_dir):
                for stream in ['stream1', 'stream2']:
                    stream_dir = os.path.join(hls_dir, stream)
                    if os.path.exists(stream_dir):
                        # Check if there are recent files
                        files = os.listdir(stream_dir)
                        ts_files = [f for f in files if f.endswith('.ts')]
                        if ts_files:
                            # Check if any file is recent (within last 30 seconds)
                            recent = False
                            for ts_file in ts_files[-5:]:  # Check last 5 files
                                file_path = os.path.join(stream_dir, ts_file)
                                if os.path.getmtime(file_path) > time.time() - 30:
                                    recent = True
                                    break
                            
                            hls_streams.append({
                                'name': stream,
                                'status': 'active' if recent else 'inactive',
                                'file_count': len(ts_files),
                                'last_update': datetime.fromtimestamp(
                                    max(os.path.getmtime(os.path.join(stream_dir, f)) 
                                        for f in ts_files)
                                ).isoformat() if ts_files else None
                            })
                        else:
                            hls_streams.append({
                                'name': stream,
                                'status': 'inactive',
                                'file_count': 0,
                                'last_update': None
                            })
            
            return {
                'status': 'success',
                'data': {
                    'active_streams': active_streams,
                    'total_viewers': total_viewers,
                    'hls_streams': hls_streams,
                    'timestamp': datetime.now().isoformat()
                }
            }
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Failed to get stream info: {str(e)}'
            }

    def control_stream(self, stream_name, action):
        """Control individual streams using nginx-rtmp control interface"""
        try:
            control_url = "http://localhost:8080/control"
            
            if action == 'stop':
                # Drop all publishers for this stream
                cmd = ['curl', '-s', f'{control_url}/drop/publisher?app=live&name={stream_name}']
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    return {
                        'status': 'success',
                        'message': f'Stream {stream_name} stopped successfully',
                        'action': action,
                        'stream': stream_name
                    }
                else:
                    return {
                        'status': 'warning',
                        'message': f'Stream {stream_name} was not active or already stopped',
                        'action': action,
                        'stream': stream_name
                    }
            
            elif action == 'start':
                # For start, we can only enable recording or redirect
                # The actual stream needs to be published via RTMP (from OBS)
                return {
                    'status': 'info',
                    'message': f'Stream {stream_name} ready for RTMP publishing. Use OBS to stream to rtmp://188.245.163.8:1935/live/{stream_name}',
                    'action': action,
                    'stream': stream_name,
                    'rtmp_url': f'rtmp://188.245.163.8:1935/live/{stream_name}'
                }
            
            elif action == 'restart':
                # First stop, then ready for start
                stop_result = self.control_stream(stream_name, 'stop')
                time.sleep(1)
                start_result = self.control_stream(stream_name, 'start')
                
                return {
                    'status': 'success',
                    'message': f'Stream {stream_name} restarted. Ready for new RTMP connection.',
                    'action': action,
                    'stream': stream_name,
                    'rtmp_url': f'rtmp://188.245.163.8:1935/live/{stream_name}'
                }
            
            else:
                return {
                    'status': 'error',
                    'message': f'Unknown action: {action}'
                }
                
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Failed to control stream {stream_name}: {str(e)}'
            }

    def handle_logs(self, query_or_data):
        """Handle log operations"""
        logs_dir = "/root/STREAMFORGE/logs"
        log_files = []
        
        if os.path.exists(logs_dir):
            for filename in os.listdir(logs_dir):
                if filename.endswith('.log'):
                    file_path = os.path.join(logs_dir, filename)
                    stat = os.stat(file_path)
                    log_files.append({
                        'name': filename,
                        'size': stat.st_size,
                        'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
                    })
        
        return {
            'status': 'success',
            'data': {
                'log_files': log_files,
                'logs_directory': logs_dir
            }
        }

    def handle_stats(self, query_or_data):
        """Get system statistics"""
        stats = {}
        
        # System uptime
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                stats['uptime_seconds'] = uptime_seconds
                stats['uptime_human'] = str(timedelta(seconds=int(uptime_seconds)))
        except:
            stats['uptime_seconds'] = 0
            stats['uptime_human'] = 'Unknown'
        
        # Memory usage
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
                for line in meminfo.split('\n'):
                    if line.startswith('MemTotal:'):
                        stats['memory_total'] = int(line.split()[1]) * 1024
                    elif line.startswith('MemAvailable:'):
                        stats['memory_available'] = int(line.split()[1]) * 1024
        except:
            stats['memory_total'] = 0
            stats['memory_available'] = 0
        
        # Load average
        try:
            with open('/proc/loadavg', 'r') as f:
                loadavg = f.read().strip().split()
                stats['load_1min'] = float(loadavg[0])
                stats['load_5min'] = float(loadavg[1])
                stats['load_15min'] = float(loadavg[2])
        except:
            stats['load_1min'] = 0.0
            stats['load_5min'] = 0.0
            stats['load_15min'] = 0.0
        
        return {
            'status': 'success',
            'data': stats
        }

    def handle_files(self, query_or_data):
        """Get file listing and management"""
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
        
        # Recordings
        recordings_dir = "/tmp/recordings"
        if os.path.exists(recordings_dir):
            files = os.listdir(recordings_dir)
            flv_files = [f for f in files if f.endswith('.flv')]
            
            if flv_files:
                total_size = sum(os.path.getsize(os.path.join(recordings_dir, f)) 
                               for f in flv_files)
                last_modified = max(os.path.getmtime(os.path.join(recordings_dir, f)) 
                                  for f in flv_files)
                
                file_info.append({
                    'path': recordings_dir,
                    'type': 'recordings',
                    'file_count': len(flv_files),
                    'total_size': total_size,
                    'last_modified': datetime.fromtimestamp(last_modified).isoformat()
                })
        
        return {
            'status': 'success',
            'data': {
                'files': file_info,
                'timestamp': datetime.now().isoformat()
            }
        }

    def log_message(self, format, *args):
        """Override to reduce logging noise"""
        pass

def run_admin_api(port=9000):
    """Run the admin API server"""
    server = HTTPServer(('0.0.0.0', port), AdminAPIHandler)
    print(f"Thunderbird Admin API running on port {port}")
    server.serve_forever()

if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9000
    run_admin_api(port)