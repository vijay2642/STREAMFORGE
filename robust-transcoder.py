#!/usr/bin/env python3
"""
StreamForge Robust Auto-Transcoder
Uses file-based mutex locks and system-wide process checking to prevent race conditions
"""

import requests
import xml.etree.ElementTree as ET
import subprocess
import time
import json
import os
import fcntl
import psutil
from datetime import datetime
from pathlib import Path

class RobustTranscoder:
    def __init__(self):
        self.nginx_stats_url = "http://localhost:8080/stat"
        self.hls_base_dir = "/tmp/hls_shared"
        self.lock_dir = "/tmp/streamforge_locks"
        
        # Create lock directory
        os.makedirs(self.lock_dir, exist_ok=True)
        
    def get_lock_file(self, stream_name):
        """Get lock file path for a stream"""
        return f"{self.lock_dir}/{stream_name}.lock"
    
    def is_stream_transcoding(self, stream_name):
        """Check if stream is already being transcoded (system-wide check)"""
        try:
            # Check for existing FFmpeg processes for this stream
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    if proc.info['name'] == 'ffmpeg':
                        cmdline = ' '.join(proc.info['cmdline'])
                        if f"rtmp://localhost:1935/live/{stream_name}" in cmdline:
                            return True, proc.info['pid']
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            return False, None
        except Exception as e:
            print(f"Error checking processes: {e}")
            return False, None
    
    def acquire_stream_lock(self, stream_name):
        """Acquire exclusive lock for a stream using file locking"""
        lock_file = self.get_lock_file(stream_name)
        try:
            # Open lock file in write mode
            lock_fd = os.open(lock_file, os.O_CREAT | os.O_WRONLY | os.O_TRUNC)
            
            # Try to acquire exclusive lock (non-blocking)
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            
            # Write PID to lock file
            os.write(lock_fd, str(os.getpid()).encode())
            os.fsync(lock_fd)
            
            return lock_fd
        except (OSError, IOError) as e:
            print(f"🔒 Stream {stream_name} is locked by another process")
            try:
                os.close(lock_fd)
            except:
                pass
            return None
    
    def release_stream_lock(self, lock_fd):
        """Release stream lock"""
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        except:
            pass
    
    def get_active_streams_from_nginx(self):
        """Get active streams from NGINX RTMP stats"""
        try:
            response = requests.get(self.nginx_stats_url, timeout=5)
            if response.status_code != 200:
                return []
                
            root = ET.fromstring(response.text)
            streams = []
            
            for stream in root.findall(".//stream"):
                name = stream.find("name")
                publishing = stream.find("publishing")
                
                if name is not None and publishing is not None:
                    streams.append(name.text)
                    
            return streams
        except Exception as e:
            print(f"Error getting NGINX stats: {e}")
            return []
    
    def start_transcoder(self, stream_name):
        """Start FFmpeg transcoder for a stream with mutex protection"""
        # First check if already transcoding (system-wide)
        is_running, existing_pid = self.is_stream_transcoding(stream_name)
        if is_running:
            print(f"⚠️  Stream {stream_name} already transcoding (PID: {existing_pid})")
            return False
        
        # Try to acquire exclusive lock
        lock_fd = self.acquire_stream_lock(stream_name)
        if not lock_fd:
            return False
        
        try:
            print(f"🚀 Starting transcoder for stream: {stream_name}")
            
            # Create output directory
            stream_dir = f"{self.hls_base_dir}/{stream_name}"
            os.makedirs(stream_dir, exist_ok=True)
            os.makedirs(f"{stream_dir}/720p", exist_ok=True)
            os.makedirs(f"{stream_dir}/480p", exist_ok=True) 
            os.makedirs(f"{stream_dir}/360p", exist_ok=True)
            
            # FFmpeg command for adaptive bitrate streaming
            cmd = [
                "ffmpeg", "-y",
                "-i", f"rtmp://localhost:1935/live/{stream_name}",
                "-hide_banner", "-loglevel", "error",
                "-fflags", "+genpts",
                "-avoid_negative_ts", "make_zero",
                
                # Map video and audio streams
                "-map", "0:v:0", "-map", "0:a:0",
                "-map", "0:v:0", "-map", "0:a:0", 
                "-map", "0:v:0", "-map", "0:a:0",
                
                # 720p stream
                "-c:v:0", "libx264", "-preset", "veryfast", "-tune", "zerolatency",
                "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
                "-force_key_frames", "expr:gte(t,n_forced*2)",
                "-filter:v:0", "scale=w=1280:h=720:force_original_aspect_ratio=decrease:force_divisible_by=2",
                "-b:v:0", "2800k", "-maxrate:v:0", "3000k", "-bufsize:v:0", "2800k",
                "-c:a:0", "aac", "-b:a:0", "128k", "-ac", "2", "-ar", "44100",
                
                # 480p stream
                "-c:v:1", "libx264", "-preset", "veryfast", "-tune", "zerolatency",
                "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
                "-force_key_frames", "expr:gte(t,n_forced*2)",
                "-filter:v:1", "scale=w=854:h=480:force_original_aspect_ratio=decrease:force_divisible_by=2",
                "-b:v:1", "1400k", "-maxrate:v:1", "1500k", "-bufsize:v:1", "1400k",
                "-c:a:1", "aac", "-b:a:1", "96k", "-ac", "2", "-ar", "44100",
                
                # 360p stream
                "-c:v:2", "libx264", "-preset", "veryfast", "-tune", "zerolatency",
                "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
                "-force_key_frames", "expr:gte(t,n_forced*2)",
                "-filter:v:2", "scale=w=640:h=360:force_original_aspect_ratio=decrease:force_divisible_by=2",
                "-b:v:2", "800k", "-maxrate:v:2", "900k", "-bufsize:v:2", "800k",
                "-c:a:2", "aac", "-b:a:2", "64k", "-ac", "2", "-ar", "44100",
                
                # HLS output - robust settings
                "-f", "hls", "-hls_time", "2", "-hls_list_size", "6",
                "-hls_flags", "delete_segments+independent_segments+program_date_time",
                "-hls_start_number_source", "epoch",
                "-hls_segment_type", "mpegts",
                "-master_pl_name", "master.m3u8",
                "-hls_segment_filename", f"{stream_dir}/%v/segment%03d.ts",
                "-var_stream_map", "v:0,a:0,name:720p v:1,a:1,name:480p v:2,a:2,name:360p",
                f"{stream_dir}/%v/playlist.m3u8"
            ]
            
            # Start FFmpeg process in background
            process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Store PID in lock file for monitoring
            lock_file = self.get_lock_file(stream_name)
            with open(f"{lock_file}.pid", "w") as f:
                f.write(str(process.pid))
            
            print(f"✅ Transcoder started for {stream_name} (PID: {process.pid})")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start transcoder for {stream_name}: {e}")
            return False
        finally:
            # Keep lock until process is confirmed running
            time.sleep(1)
            self.release_stream_lock(lock_fd)
    
    def stop_transcoder(self, stream_name):
        """Stop FFmpeg transcoder for a stream"""
        try:
            # Find and kill FFmpeg process for this stream
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    if proc.info['name'] == 'ffmpeg':
                        cmdline = ' '.join(proc.info['cmdline'])
                        if f"rtmp://localhost:1935/live/{stream_name}" in cmdline:
                            print(f"🛑 Stopping transcoder for stream: {stream_name} (PID: {proc.info['pid']})")
                            proc.terminate()
                            proc.wait(timeout=5)
                            
                            # Clean up lock files
                            lock_file = self.get_lock_file(stream_name)
                            try:
                                os.remove(lock_file)
                                os.remove(f"{lock_file}.pid")
                            except FileNotFoundError:
                                pass
                            
                            print(f"✅ Transcoder stopped for {stream_name}")
                            return True
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.TimeoutExpired):
                    continue
            
            print(f"⚠️  No transcoder found for {stream_name}")
            return False
            
        except Exception as e:
            print(f"❌ Error stopping transcoder for {stream_name}: {e}")
            return False
    
    def cleanup_stale_locks(self):
        """Clean up stale lock files from dead processes"""
        try:
            for lock_file in Path(self.lock_dir).glob("*.lock"):
                try:
                    with open(lock_file, 'r') as f:
                        pid = int(f.read().strip())
                    
                    # Check if process still exists
                    if not psutil.pid_exists(pid):
                        print(f"🧹 Cleaning stale lock: {lock_file.name}")
                        lock_file.unlink()
                        pid_file = Path(f"{lock_file}.pid")
                        if pid_file.exists():
                            pid_file.unlink()
                            
                except (ValueError, FileNotFoundError):
                    # Invalid or missing PID, remove lock
                    lock_file.unlink()
        except Exception as e:
            print(f"Error cleaning locks: {e}")
    
    def monitor_loop(self):
        """Main monitoring loop with robust concurrency control"""
        print("🎬 StreamForge Robust Auto-Transcoder started")
        print("🔒 Using file-based mutex locks for concurrency control")
        print("📡 Monitoring NGINX RTMP for new streams...")
        
        while True:
            try:
                # Clean up stale locks first
                self.cleanup_stale_locks()
                
                # Get current streams from NGINX
                current_streams = set(self.get_active_streams_from_nginx())
                
                # Get currently transcoding streams (system-wide check)
                active_transcoders = set()
                for stream in ['stream1', 'stream2', 'stream3', 'stream4', 'stream5']:
                    is_running, _ = self.is_stream_transcoding(stream)
                    if is_running:
                        active_transcoders.add(stream)
                
                # Start transcoders for new streams
                new_streams = current_streams - active_transcoders
                for stream in new_streams:
                    self.start_transcoder(stream)
                
                # Stop transcoders for disconnected streams
                stopped_streams = active_transcoders - current_streams
                for stream in stopped_streams:
                    self.stop_transcoder(stream)
                
                # Status update
                if current_streams:
                    print(f"📊 NGINX streams: {', '.join(current_streams)} | Transcoders: {', '.join(active_transcoders)}")
                
                time.sleep(5)  # Check every 5 seconds
                
            except KeyboardInterrupt:
                print("🛑 Shutting down...")
                break
            except Exception as e:
                print(f"❌ Error in monitor loop: {e}")
                time.sleep(5)
        
        # Cleanup on exit
        print("🧹 Cleaning up...")
        for stream in ['stream1', 'stream2', 'stream3', 'stream4', 'stream5']:
            self.stop_transcoder(stream)

if __name__ == "__main__":
    transcoder = RobustTranscoder()
    transcoder.monitor_loop()