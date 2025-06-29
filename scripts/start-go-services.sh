#!/bin/bash

# StreamForge Go Services Startup Script
# Replaces all Python services with high-performance Go alternatives

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✅ $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠️  $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ❌ $1"
}

# Configuration
PROJECT_ROOT="/root/STREAMFORGE"
LOG_DIR="$PROJECT_ROOT/logs"
HLS_DIR="/tmp/hls_shared"

# Service configurations
TRANSCODER_PORT=8083
HLS_SERVER_PORT=8085
ADMIN_API_PORT=9000

# Create necessary directories
log "Creating necessary directories..."
mkdir -p "$LOG_DIR" "$HLS_DIR"
chmod 755 "$LOG_DIR" "$HLS_DIR"

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to stop service on port
stop_service_on_port() {
    local port=$1
    local service_name=$2
    
    if check_port $port; then
        warn "Port $port is already in use. Stopping existing $service_name..."
        local pids=$(lsof -ti:$port)
        if [ ! -z "$pids" ]; then
            echo "$pids" | xargs kill -9
            sleep 2
            success "Stopped existing $service_name on port $port"
        fi
    fi
}

# Function to build Go service
build_go_service() {
    local service_dir=$1
    local service_name=$2
    
    log "Building $service_name..."
    cd "$service_dir"
    
    if [ ! -f "go.mod" ]; then
        go mod init "github.com/streamforge/platform/services/$service_name"
        go mod tidy
    fi
    
    if go build -o "$service_name" .; then
        success "$service_name built successfully"
        return 0
    else
        error "Failed to build $service_name"
        return 1
    fi
}

# Function to start Go service
start_go_service() {
    local service_dir=$1
    local service_name=$2
    local port=$3
    local additional_args=${4:-}
    
    cd "$service_dir"
    
    if [ ! -f "$service_name" ]; then
        error "$service_name binary not found. Build failed?"
        return 1
    fi
    
    log "Starting $service_name on port $port..."
    
    # Set environment variables
    export PORT=$port
    export HLS_DIR="$HLS_DIR"
    export OUTPUT_DIR="$HLS_DIR"
    export RTMP_URL="rtmp://localhost:1935/live"
    
    nohup ./"$service_name" $additional_args > "$LOG_DIR/$service_name.log" 2>&1 &
    local pid=$!
    
    # Wait a moment and check if the service started successfully
    sleep 3
    if kill -0 $pid 2>/dev/null; then
        success "$service_name started successfully (PID: $pid)"
        echo $pid > "$LOG_DIR/$service_name.pid"
        return 0
    else
        error "$service_name failed to start"
        return 1
    fi
}

# Function to stop all Python services
stop_python_services() {
    log "Stopping any running Python services..."
    
    # Stop Python CORS server
    pkill -f "cors_server.py" || true
    
    # Stop Python admin API
    pkill -f "admin.py" || true
    
    # Stop any other Python HTTP servers
    pkill -f "python.*http" || true
    pkill -f "python.*server" || true
    
    success "Python services stopped"
}

# Main execution
main() {
    log "🚀 Starting StreamForge Go Services (Python-free stack)"
    log "⚡ Maximum performance mode enabled"
    
    # Stop Python services first
    stop_python_services
    
    # Stop services on required ports
    stop_service_on_port $TRANSCODER_PORT "transcoder"
    stop_service_on_port $HLS_SERVER_PORT "HLS server"
    stop_service_on_port $ADMIN_API_PORT "admin API"
    
    # Build and start Transcoder Service
    if build_go_service "$PROJECT_ROOT/services/transcoder" "transcoder"; then
        start_go_service "$PROJECT_ROOT/services/transcoder" "transcoder" $TRANSCODER_PORT
    else
        error "Failed to start transcoder service"
        exit 1
    fi
    
    # Build and start HLS Server
    if build_go_service "$PROJECT_ROOT/services/hls-server" "hls-server"; then
        start_go_service "$PROJECT_ROOT/services/hls-server" "hls-server" $HLS_SERVER_PORT
    else
        error "Failed to start HLS server"
        exit 1
    fi
    
    # Build and start Admin API
    if build_go_service "$PROJECT_ROOT/services/admin-api" "admin-api"; then
        start_go_service "$PROJECT_ROOT/services/admin-api" "admin-api" $ADMIN_API_PORT
    else
        error "Failed to start admin API"
        exit 1
    fi
    
    # Wait for services to fully start
    log "Waiting for services to start..."
    sleep 5
    
    # Verify services are running
    log "Verifying services..."
    
    services_ok=true
    
    if check_port $TRANSCODER_PORT; then
        success "Transcoder service running on port $TRANSCODER_PORT"
    else
        error "Transcoder service not responding on port $TRANSCODER_PORT"
        services_ok=false
    fi
    
    if check_port $HLS_SERVER_PORT; then
        success "HLS server running on port $HLS_SERVER_PORT"
    else
        error "HLS server not responding on port $HLS_SERVER_PORT"
        services_ok=false
    fi
    
    if check_port $ADMIN_API_PORT; then
        success "Admin API running on port $ADMIN_API_PORT"
    else
        error "Admin API not responding on port $ADMIN_API_PORT"
        services_ok=false
    fi
    
    if $services_ok; then
        success "🎉 All Go services started successfully!"
        log ""
        log "🌐 Service endpoints:"
        log "   - Transcoder API: http://localhost:$TRANSCODER_PORT"
        log "   - HLS File Server: http://localhost:$HLS_SERVER_PORT"
        log "   - Admin API: http://localhost:$ADMIN_API_PORT"
        log ""
        log "📊 Service health checks:"
        log "   - Transcoder: http://localhost:$TRANSCODER_PORT/health"
        log "   - HLS Server: http://localhost:$HLS_SERVER_PORT/health"
        log "   - Admin API: http://localhost:$ADMIN_API_PORT/health"
        log ""
        log "📁 Logs available in: $LOG_DIR"
        log "🎬 HLS files served from: $HLS_DIR"
        log ""
        success "⚡ Python eliminated - Maximum performance achieved!"
    else
        error "Some services failed to start. Check logs in $LOG_DIR"
        exit 1
    fi
}

# Run main function
main "$@"