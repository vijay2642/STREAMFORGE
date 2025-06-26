#!/bin/bash

# Enhanced StreamForge Shutdown Script

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🛑 Stopping Enhanced StreamForge Services..."

# Function to stop a service by PID file
stop_by_pidfile() {
    local service_name=$1
    local pidfile=$2
    
    if [ -f "$pidfile" ]; then
        PID=$(cat "$pidfile")
        if kill -0 $PID 2>/dev/null; then
            echo "🔴 Stopping $service_name (PID: $PID)..."
            kill $PID
            sleep 1
            
            # Force kill if still running
            if kill -0 $PID 2>/dev/null; then
                echo "⚠️  Force killing $service_name..."
                kill -9 $PID
            fi
        fi
        rm -f "$pidfile"
    fi
}

# 1. Stop test streams if running
stop_by_pidfile "Stream Generator" "$PROJECT_ROOT/logs/streamgen.pid"

# 2. Stop all transcoders
echo "🎬 Stopping all transcoders..."
curl -s http://localhost:8083/transcode/active | jq -r '.data[].stream_key' 2>/dev/null | while read stream; do
    if [ ! -z "$stream" ]; then
        echo "  • Stopping transcoder for $stream"
        curl -X POST "http://localhost:8083/transcode/stop/$stream" 2>/dev/null
    fi
done

# 3. Stop transcoder service
stop_by_pidfile "Transcoder Service" "$PROJECT_ROOT/logs/transcoder.pid"

# 4. Stop web proxy
stop_by_pidfile "Web Proxy" "$PROJECT_ROOT/logs/web-proxy.pid"

# 5. Stop NGINX
echo "🎥 Stopping NGINX-RTMP..."
sudo nginx -s stop 2>/dev/null || true

# 6. Clean up HLS files
echo "🧹 Cleaning up HLS files..."
rm -rf /tmp/hls_shared/*
rm -rf /tmp/hls/*

echo "✅ All services stopped!"