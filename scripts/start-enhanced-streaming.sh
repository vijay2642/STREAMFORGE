#!/bin/bash

# Enhanced StreamForge Startup Script
# Uses Go-based services for optimal performance

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Enhanced StreamForge Services..."

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p /tmp/hls_shared
mkdir -p "$PROJECT_ROOT/logs"

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ $service_name is already running on port $port"
        return 0
    else
        return 1
    fi
}

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=0
    
    echo -n "⏳ Waiting for $service_name to start..."
    while [ $attempt -lt $max_attempts ]; do
        if nc -z localhost $port 2>/dev/null; then
            echo " ✅"
            return 0
        fi
        echo -n "."
        sleep 1
        ((attempt++))
    done
    echo " ❌ Failed to start!"
    return 1
}

# 1. Start NGINX with RTMP module
if ! check_service "NGINX-RTMP" 1935; then
    echo "🎥 Starting NGINX-RTMP server..."
    
    # Check if custom config exists, otherwise use default
    NGINX_CONF="$PROJECT_ROOT/services/nginx-rtmp/nginx-enhanced.conf"
    if [ ! -f "$NGINX_CONF" ]; then
        NGINX_CONF="$PROJECT_ROOT/services/nginx-rtmp/nginx-rtmp.conf"
    fi
    
    # Stop any existing nginx
    sudo nginx -s stop 2>/dev/null || true
    sleep 1
    
    # Start with our config
    sudo nginx -c "$NGINX_CONF" &
    
    wait_for_service "NGINX-RTMP" 1935
    wait_for_service "NGINX-HTTP" 8080
fi

# 2. Start Go Transcoder Service
if ! check_service "Transcoder" 8083; then
    echo "🎬 Building and starting Go Transcoder Service..."
    
    cd "$PROJECT_ROOT/services/transcoder"
    
    # Build if not exists
    if [ ! -f "transcoder" ]; then
        echo "🔨 Building transcoder service..."
        go build -o transcoder .
    fi
    
    # Start transcoder
    OUTPUT_DIR="/tmp/hls_shared"
    ./transcoder \
        -port 8083 \
        -rtmp-url "rtmp://localhost:1935/live" \
        -output-dir "$OUTPUT_DIR" \
        > "$PROJECT_ROOT/logs/transcoder.log" 2>&1 &
    
    echo "📝 Transcoder PID: $!"
    echo $! > "$PROJECT_ROOT/logs/transcoder.pid"
    
    wait_for_service "Transcoder" 8083
fi

# 3. Start test streams (optional)
if [ "$1" == "--with-test-streams" ]; then
    echo "🧪 Starting test streams..."
    
    cd "$PROJECT_ROOT/cmd/streamgen"
    
    # Build stream generator if not exists
    if [ ! -f "streamgen" ]; then
        echo "🔨 Building stream generator..."
        go build -o streamgen .
    fi
    
    # Start test streams
    ./streamgen -cmd start -streams all &
    STREAMGEN_PID=$!
    echo "📝 Stream generator PID: $STREAMGEN_PID"
    echo $STREAMGEN_PID > "$PROJECT_ROOT/logs/streamgen.pid"
    
    # Wait for streams to initialize
    sleep 3
    
    # Start transcoders for test streams
    echo "🎯 Starting transcoders for test streams..."
    for stream in stream1 stream2 stream3; do
        curl -X POST "http://localhost:8083/transcode/start/$stream"
        echo
        sleep 1
    done
fi

# 4. Start web proxy server
if ! check_service "Web Proxy" 3000; then
    echo "🌐 Starting web proxy server..."
    
    cd "$PROJECT_ROOT/web"
    python3 -m http.server 3000 \
        --bind 0.0.0.0 \
        > "$PROJECT_ROOT/logs/web-proxy.log" 2>&1 &
    
    echo "📝 Web proxy PID: $!"
    echo $! > "$PROJECT_ROOT/logs/web-proxy.pid"
    
    wait_for_service "Web Proxy" 3000
fi

echo ""
echo "✅ Enhanced StreamForge is ready!"
echo ""
echo "📊 Service Status:"
echo "  • NGINX-RTMP: http://localhost:8080/stat"
echo "  • Transcoder API: http://localhost:8083/health"
echo "  • Web Interface: http://localhost:3000"
echo ""
echo "🎬 Available Endpoints:"
echo "  • Live Player: http://localhost:3000/live-player.html"
echo "  • Multi-Quality Player: http://localhost:3000/index.html"
echo "  • Adaptive Player: http://localhost:3000/adaptive-live-player.html"
echo ""

if [ "$1" == "--with-test-streams" ]; then
    echo "🧪 Test Streams Active:"
    echo "  • stream1: http://localhost:8083/hls/stream1/master.m3u8"
    echo "  • stream2: http://localhost:8083/hls/stream2/master.m3u8"
    echo "  • stream3: http://localhost:8083/hls/stream3/master.m3u8"
    echo ""
fi

echo "🛑 To stop all services, run: $SCRIPT_DIR/stop-enhanced-streaming.sh"