#!/bin/bash

# StreamForge Live Streaming Platform - Comprehensive Startup Script
# Starts all services with proper dependency management and CORS configuration
# Supports buffer-free multi-quality adaptive streaming

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"
HLS_OUTPUT_DIR="/tmp/hls_shared"
NGINX_CONFIG="$PROJECT_ROOT/services/nginx-rtmp/nginx-enhanced.conf"
TRANSCODER_DIR="$PROJECT_ROOT/services/transcoder"
WEB_DIR="$PROJECT_ROOT/web"

# Service ports
RTMP_PORT=1935
HTTP_PORT=8080
TRANSCODER_PORT=8083
WEB_PORT=3000

# PID files
NGINX_PID="$LOGS_DIR/nginx.pid"
TRANSCODER_PID="$LOGS_DIR/transcoder.pid"
WEB_PID="$LOGS_DIR/web.pid"

# Logging function
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/streamforge-startup.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/streamforge-startup.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/streamforge-startup.log"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGS_DIR/streamforge-startup.log"
}

# Check if port is available
check_port_available() {
    local port=$1
    local service_name=$2

    # Check with multiple methods
    local port_in_use=false

    # Method 1: netstat
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        port_in_use=true
    fi

    # Method 2: ss (more reliable)
    if command -v ss >/dev/null 2>&1 && ss -tuln 2>/dev/null | grep -q ":$port "; then
        port_in_use=true
    fi

    # Method 3: lsof
    if command -v lsof >/dev/null 2>&1 && lsof -i :$port >/dev/null 2>&1; then
        port_in_use=true
    fi

    if [ "$port_in_use" = true ]; then
        warning "Port $port appears to be in use (needed for $service_name)"
        echo "  Attempting to clean up existing processes..."

        # Try to find and kill processes using this port
        local pids=$(lsof -t -i :$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            echo "  Found processes using port $port: $pids"
            echo "  Killing processes..."
            echo "$pids" | xargs kill -TERM 2>/dev/null || true
            sleep 2

            # Force kill if still running
            local remaining_pids=$(lsof -t -i :$port 2>/dev/null || true)
            if [ -n "$remaining_pids" ]; then
                echo "  Force killing remaining processes..."
                echo "$remaining_pids" | xargs kill -9 2>/dev/null || true
                sleep 1
            fi
        fi

        # Check again after cleanup
        if lsof -i :$port >/dev/null 2>&1; then
            error "Port $port is still in use after cleanup attempt"
            echo "  Manual cleanup required:"
            echo "  sudo lsof -i :$port"
            echo "  sudo kill \$(sudo lsof -t -i :$port)"
            return 1
        else
            success "✅ Port $port cleaned up successfully"
        fi
    fi
    return 0
}

# Wait for service to be ready
wait_for_service() {
    local service_name=$1
    local port=$2
    local timeout=${3:-30}
    local count=0
    
    log "⏳ Waiting for $service_name to be ready on port $port..."
    
    while [ $count -lt $timeout ]; do
        if curl -s "http://localhost:$port/health" >/dev/null 2>&1 || \
           curl -s "http://localhost:$port/" >/dev/null 2>&1; then
            success "✅ $service_name is ready!"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    echo ""
    error "❌ $service_name failed to start within $timeout seconds"
    return 1
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check required commands
    local missing_deps=()
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        missing_deps+=("ffmpeg")
    fi
    
    if ! command -v go >/dev/null 2>&1; then
        missing_deps+=("go")
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
    
    success "✅ All prerequisites are available"
}

# Setup directories
setup_directories() {
    log "📁 Setting up directories..."
    
    # Create logs directory
    mkdir -p "$LOGS_DIR"
    
    # Create HLS output directory with proper permissions
    sudo mkdir -p "$HLS_OUTPUT_DIR"
    sudo chmod 755 "$HLS_OUTPUT_DIR"
    
    # Ensure transcoding script is executable
    if [ -f "$PROJECT_ROOT/scripts/transcode.sh" ]; then
        chmod +x "$PROJECT_ROOT/scripts/transcode.sh"
        success "✅ Transcoding script is executable"
    else
        error "❌ Transcoding script not found at $PROJECT_ROOT/scripts/transcode.sh"
        exit 1
    fi
    
    success "✅ Directories setup complete"
}

# Verify configurations
verify_config() {
    log "🔧 Verifying configurations..."
    
    # Check NGINX config exists
    if [ ! -f "$NGINX_CONFIG" ]; then
        error "❌ NGINX configuration not found: $NGINX_CONFIG"
        exit 1
    fi
    
    # Check if exec directive is present
    if ! grep -q "exec.*transcode.sh" "$NGINX_CONFIG"; then
        error "❌ NGINX config missing exec directive for automatic transcoding"
        exit 1
    fi
    
    # Check transcoding script syntax
    if ! bash -n "$PROJECT_ROOT/scripts/transcode.sh"; then
        error "❌ Transcoding script has syntax errors"
        exit 1
    fi
    
    success "✅ Configuration verification complete"
}

# Check port availability
check_ports() {
    log "🔌 Checking port availability..."
    
    check_port_available $RTMP_PORT "NGINX-RTMP" || exit 1
    check_port_available $HTTP_PORT "NGINX-HTTP" || exit 1
    check_port_available $TRANSCODER_PORT "Transcoder Service" || exit 1
    check_port_available $WEB_PORT "Web Server" || exit 1
    
    success "✅ All required ports are available"
}

# Start NGINX-RTMP server
start_nginx_rtmp() {
    log "🎬 Starting NGINX-RTMP server..."

    # Check if Docker is available and preferred
    if command -v docker >/dev/null 2>&1; then
        log "🐳 Using Docker for NGINX-RTMP..."

        # Stop any existing container
        docker stop streamforge-nginx 2>/dev/null || true
        docker rm streamforge-nginx 2>/dev/null || true

        # Build and start NGINX container
        cd "$PROJECT_ROOT"

        # Build with proper context from project root
        docker build -t streamforge-nginx -f ./services/nginx-rtmp/Dockerfile ./services/nginx-rtmp/

        docker run -d \
            --name streamforge-nginx \
            -p $RTMP_PORT:1935 \
            -p $HTTP_PORT:8080 \
            -v "$HLS_OUTPUT_DIR:/tmp/hls" \
            -v "$PROJECT_ROOT/scripts:/scripts" \
            -v "$LOGS_DIR:/logs" \
            streamforge-nginx

        # Wait for container to be ready
        sleep 3

        if docker ps | grep -q streamforge-nginx; then
            echo "$(docker ps --format 'table {{.ID}}' --filter name=streamforge-nginx | tail -n1)" > "$NGINX_PID"
            success "✅ NGINX-RTMP started in Docker container"
        else
            error "❌ Failed to start NGINX-RTMP container"
            docker logs streamforge-nginx
            exit 1
        fi
    else
        error "❌ Docker not available. Please install Docker or implement native NGINX startup."
        exit 1
    fi
}

# Start Go transcoder monitoring service
start_transcoder_service() {
    log "📊 Starting Go transcoder monitoring service..."

    cd "$TRANSCODER_DIR"

    # Build if binary doesn't exist or source is newer
    if [ ! -f "transcoder" ] || [ "main.go" -nt "transcoder" ]; then
        log "🔨 Building transcoder service..."
        if ! go build -o transcoder .; then
            error "❌ Failed to build transcoder service"
            exit 1
        fi
        success "✅ Transcoder service built successfully"
    fi

    # Start the service
    ./transcoder \
        -port $TRANSCODER_PORT \
        -rtmp-url "rtmp://localhost:$RTMP_PORT/live" \
        -output-dir "$HLS_OUTPUT_DIR" \
        > "$LOGS_DIR/transcoder.log" 2>&1 &

    echo $! > "$TRANSCODER_PID"

    # Wait for service to be ready
    if wait_for_service "Transcoder Service" $TRANSCODER_PORT; then
        success "✅ Transcoder monitoring service started (PID: $(cat $TRANSCODER_PID))"
    else
        error "❌ Failed to start transcoder service"
        cat "$LOGS_DIR/transcoder.log"
        exit 1
    fi
}

# Start web server for player interface
start_web_server() {
    log "🌐 Starting web server for player interface..."

    # Clean up any existing web server processes
    if [ -f "$WEB_PID" ]; then
        local old_pid=$(cat "$WEB_PID" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            log "Stopping existing web server (PID: $old_pid)..."
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$WEB_PID"
    fi

    # Kill any Python processes on port 3000
    local python_pids=$(lsof -t -i :$WEB_PORT 2>/dev/null | grep -v "^$" || true)
    if [ -n "$python_pids" ]; then
        log "Cleaning up existing processes on port $WEB_PORT..."
        echo "$python_pids" | xargs kill -TERM 2>/dev/null || true
        sleep 2
    fi

    cd "$WEB_DIR"

    # Create a simple Python server with CORS support
    cat > cors_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
from http.server import SimpleHTTPRequestHandler
import sys
import time
import socket

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # Set proper MIME types for video files
        if self.path.endswith('.m3u8'):
            self.send_header('Content-Type', 'application/vnd.apple.mpegurl')
        elif self.path.endswith('.ts'):
            self.send_header('Content-Type', 'video/mp2t')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging to reduce noise
        pass

if __name__ == "__main__":
    PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000

    # Try to bind to the port with retries
    max_retries = 5
    for attempt in range(max_retries):
        try:
            # Allow socket reuse
            socketserver.TCPServer.allow_reuse_address = True
            with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
                print(f"Server running on port {PORT}")
                httpd.serve_forever()
                break
        except OSError as e:
            if e.errno == 98:  # Address already in use
                print(f"Port {PORT} in use, attempt {attempt + 1}/{max_retries}")
                if attempt < max_retries - 1:
                    time.sleep(2)
                    continue
                else:
                    print(f"Failed to bind to port {PORT} after {max_retries} attempts")
                    sys.exit(1)
            else:
                print(f"Error starting server: {e}")
                sys.exit(1)
EOF

    # Start the web server
    python3 cors_server.py $WEB_PORT > "$LOGS_DIR/web.log" 2>&1 &
    echo $! > "$WEB_PID"

    # Wait for service to be ready
    if wait_for_service "Web Server" $WEB_PORT; then
        success "✅ Web server started (PID: $(cat $WEB_PID))"
    else
        error "❌ Failed to start web server"
        cat "$LOGS_DIR/web.log"
        exit 1
    fi
}

# Display final status and instructions
display_status() {
    echo ""
    echo -e "${PURPLE}🎉 StreamForge Live Streaming Platform Started Successfully!${NC}"
    echo -e "${PURPLE}================================================================${NC}"
    echo ""

    echo -e "${GREEN}📡 RTMP Streaming Endpoint:${NC}"
    echo -e "   Server: ${CYAN}rtmp://$(hostname -I | awk '{print $1}'):$RTMP_PORT/live${NC}"
    echo -e "   Example Stream Keys: ${YELLOW}stream1, stream2, stream3${NC}"
    echo ""

    echo -e "${GREEN}🎬 HLS Streaming URLs:${NC}"
    echo -e "   Master Playlist: ${CYAN}http://$(hostname -I | awk '{print $1}'):$HTTP_PORT/hls/{stream_key}/master.m3u8${NC}"
    echo -e "   Example: ${CYAN}http://$(hostname -I | awk '{print $1}'):$HTTP_PORT/hls/stream1/master.m3u8${NC}"
    echo ""

    echo -e "${GREEN}🌐 Web Player Interface:${NC}"
    echo -e "   Adaptive Player: ${CYAN}http://$(hostname -I | awk '{print $1}'):$WEB_PORT/adaptive-live-player.html${NC}"
    echo -e "   Live Player: ${CYAN}http://$(hostname -I | awk '{print $1}'):$WEB_PORT/live-player.html${NC}"
    echo ""

    echo -e "${GREEN}📊 Monitoring & APIs:${NC}"
    echo -e "   Transcoder Status: ${CYAN}http://localhost:$TRANSCODER_PORT/transcode/active${NC}"
    echo -e "   NGINX Stats: ${CYAN}http://localhost:$HTTP_PORT/stat${NC}"
    echo -e "   Health Check: ${CYAN}http://localhost:$TRANSCODER_PORT/health${NC}"
    echo ""

    echo -e "${GREEN}🎯 Quality Levels Available:${NC}"
    echo -e "   • ${YELLOW}720p${NC} - 2800k bitrate (1280x720)"
    echo -e "   • ${YELLOW}480p${NC} - 1400k bitrate (854x480)"
    echo -e "   • ${YELLOW}360p${NC} - 800k bitrate (640x360)"
    echo ""

    echo -e "${GREEN}📝 OBS Configuration:${NC}"
    echo -e "   1. Go to Settings > Stream"
    echo -e "   2. Set Service to 'Custom...'"
    echo -e "   3. Set Server to: ${CYAN}rtmp://$(hostname -I | awk '{print $1}'):$RTMP_PORT/live${NC}"
    echo -e "   4. Set Stream Key to: ${YELLOW}your-stream-name${NC} (e.g., stream1)"
    echo -e "   5. Start Streaming!"
    echo ""

    echo -e "${GREEN}🔄 Automatic Features:${NC}"
    echo -e "   ✅ Transcoding starts automatically when you begin streaming"
    echo -e "   ✅ Multiple quality levels created with perfect keyframe alignment"
    echo -e "   ✅ Buffer-free quality switching in players"
    echo -e "   ✅ CORS headers configured for cross-origin access"
    echo ""

    echo -e "${GREEN}📋 Log Files:${NC}"
    echo -e "   • Startup: ${CYAN}$LOGS_DIR/streamforge-startup.log${NC}"
    echo -e "   • NGINX: ${CYAN}docker logs streamforge-nginx${NC}"
    echo -e "   • Transcoder: ${CYAN}$LOGS_DIR/transcoder.log${NC}"
    echo -e "   • Web Server: ${CYAN}$LOGS_DIR/web.log${NC}"
    echo -e "   • Stream Transcoding: ${CYAN}$LOGS_DIR/transcode_{stream_key}.log${NC}"
    echo ""

    echo -e "${YELLOW}💡 Tips:${NC}"
    echo -e "   • Use ${CYAN}./stop-streamforge.sh${NC} to stop all services"
    echo -e "   • Monitor transcoding: ${CYAN}tail -f $LOGS_DIR/transcode_*.log${NC}"
    echo -e "   • Check active streams: ${CYAN}curl http://localhost:$TRANSCODER_PORT/transcode/active${NC}"
    echo ""
}

# Cleanup function for error handling
cleanup_on_error() {
    error "❌ Startup failed. Cleaning up..."

    # Stop any services that might have started
    if [ -f "$WEB_PID" ]; then
        kill "$(cat $WEB_PID)" 2>/dev/null || true
        rm -f "$WEB_PID"
    fi

    if [ -f "$TRANSCODER_PID" ]; then
        kill "$(cat $TRANSCODER_PID)" 2>/dev/null || true
        rm -f "$TRANSCODER_PID"
    fi

    if [ -f "$NGINX_PID" ]; then
        docker stop streamforge-nginx 2>/dev/null || true
        docker rm streamforge-nginx 2>/dev/null || true
        rm -f "$NGINX_PID"
    fi

    exit 1
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_error ERR

    echo -e "${PURPLE}🚀 Starting StreamForge Live Streaming Platform${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo ""

    # Initialize logging
    mkdir -p "$LOGS_DIR"
    echo "StreamForge startup initiated at $(date)" > "$LOGS_DIR/streamforge-startup.log"

    # Run startup sequence
    check_prerequisites
    setup_directories
    verify_config
    check_ports

    echo ""
    log "🎬 Starting services in dependency order..."
    echo ""

    start_nginx_rtmp
    start_transcoder_service
    start_web_server

    # Final status display
    display_status

    success "🎉 StreamForge is ready for multi-stream adaptive streaming!"
}

# Run main function
main "$@"
