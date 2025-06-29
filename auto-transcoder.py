#!/usr/bin/env python3
"""
StreamForge Auto-Transcoder
Monitors NGINX RTMP stats and automatically starts/stops FFmpeg transcoders
"""

import requests
import xml.etree.ElementTree as ET
import subprocess
import time
import json
import os
from datetime import datetime

class AutoTranscoder:
    def __init__(self):
        self.active_streams = {}
        self.nginx_stats_url = "http://localhost:8080/stat"
        self.hls_base_dir = "/tmp/hls_shared"
        
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
        """Start FFmpeg transcoder for a stream"""
        if stream_name in self.active_streams:
            return
            
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
            "-hide_banner", "-loglevel", "info",
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
            
            # HLS output - optimized for low latency
            "-f", "hls", "-hls_time", "2", "-hls_list_size", "6",
            "-hls_flags", "delete_segments+independent_segments+program_date_time",
            "-hls_start_number_source", "epoch",
            "-hls_segment_type", "mpegts",
            "-master_pl_name", "master.m3u8",
            "-hls_segment_filename", f"{stream_dir}/%v/segment%03d.ts",
            "-var_stream_map", "v:0,a:0,name:720p v:1,a:1,name:480p v:2,a:2,name:360p",
            f"{stream_dir}/%v/playlist.m3u8"
        ]
        
        # Start FFmpeg process
        try:
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.active_streams[stream_name] = {
                "process": process,
                "started": datetime.now(),
                "cmd": cmd
            }
            print(f"✅ Transcoder started for {stream_name} (PID: {process.pid})")
        except Exception as e:
            print(f"❌ Failed to start transcoder for {stream_name}: {e}")
    
    def stop_transcoder(self, stream_name):
        """Stop FFmpeg transcoder for a stream"""
        if stream_name not in self.active_streams:
            return
            
        print(f"🛑 Stopping transcoder for stream: {stream_name}")
        
        try:
            process = self.active_streams[stream_name]["process"]
            process.terminate()
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        except Exception as e:
            print(f"Error stopping transcoder for {stream_name}: {e}")
        
        del self.active_streams[stream_name]
        print(f"✅ Transcoder stopped for {stream_name}")
    
    def monitor_loop(self):
        """Main monitoring loop"""
        print("🎬 StreamForge Auto-Transcoder started")
        print("📡 Monitoring NGINX RTMP for new streams...")
        
        while True:
            try:
                # Get current streams from NGINX
                current_streams = set(self.get_active_streams_from_nginx())
                active_transcoders = set(self.active_streams.keys())
                
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
                    print(f"📊 Active streams: {', '.join(current_streams)}")
                
                time.sleep(5)  # Check every 5 seconds
                
            except KeyboardInterrupt:
                print("🛑 Shutting down...")
                break
            except Exception as e:
                print(f"❌ Error in monitor loop: {e}")
                time.sleep(5)
        
        # Cleanup on exit
        for stream in list(self.active_streams.keys()):
            self.stop_transcoder(stream)

if __name__ == "__main__":
    transcoder = AutoTranscoder()
    transcoder.monitor_loop()