#!/bin/bash

# StreamForge Live Streaming Platform - Comprehensive Shutdown Script
# Gracefully stops all services and cleans up processes

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
HLS_OUTPUT_DIR="/tmp/hls"

# PID files
NGINX_PID="$LOGS_DIR/nginx.pid"
TRANSCODER_PID="$LOGS_DIR/transcoder.pid"
WEB_PID="$LOGS_DIR/web.pid"

# Options
CLEAN_HLS=false
PRESERVE_LOGS=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean-hls)
            CLEAN_HLS=true
            shift
            ;;
        --clean-logs)
            PRESERVE_LOGS=false
            shift
            ;;
        -h|--help)
            echo "StreamForge Stop Script"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean-hls     Remove all HLS files from /tmp/hls"
            echo "  --clean-logs    Remove all log files"
            echo "  -h, --help      Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/streamforge-shutdown.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/streamforge-shutdown.log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/streamforge-shutdown.log"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGS_DIR/streamforge-shutdown.log"
}

# Stop web server
stop_web_server() {
    log "🌐 Stopping web server..."
    
    if [ -f "$WEB_PID" ]; then
        local pid=$(cat "$WEB_PID")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping web server (PID: $pid)..."
            kill "$pid"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                warning "Force killing web server..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            
            success "✅ Web server stopped"
        else
            warning "Web server PID file exists but process not running"
        fi
        rm -f "$WEB_PID"
    else
        log "No web server PID file found"
    fi
    
    # Clean up any remaining Python servers on port 3000
    local remaining_pids=$(lsof -t -i :3000 2>/dev/null || true)
    if [ -n "$remaining_pids" ]; then
        warning "Cleaning up remaining processes on port 3000..."
        echo "$remaining_pids" | xargs kill -9 2>/dev/null || true
    fi
}

# Stop transcoder monitoring service
stop_transcoder_service() {
    log "📊 Stopping transcoder monitoring service..."
    
    if [ -f "$TRANSCODER_PID" ]; then
        local pid=$(cat "$TRANSCODER_PID")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping transcoder service (PID: $pid)..."
            kill "$pid"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 15 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                warning "Force killing transcoder service..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            
            success "✅ Transcoder service stopped"
        else
            warning "Transcoder PID file exists but process not running"
        fi
        rm -f "$TRANSCODER_PID"
    else
        log "No transcoder PID file found"
    fi
    
    # Clean up any remaining transcoder processes
    local remaining_pids=$(pgrep -f "transcoder.*8083" 2>/dev/null || true)
    if [ -n "$remaining_pids" ]; then
        warning "Cleaning up remaining transcoder processes..."
        echo "$remaining_pids" | xargs kill -9 2>/dev/null || true
    fi
}

# Stop NGINX-RTMP server
stop_nginx_rtmp() {
    log "🎬 Stopping NGINX-RTMP server..."
    
    # Stop Docker container if running
    if docker ps --format '{{.Names}}' | grep -q "streamforge-nginx"; then
        log "Stopping NGINX Docker container..."
        docker stop streamforge-nginx
        docker rm streamforge-nginx
        success "✅ NGINX-RTMP Docker container stopped"
    else
        log "No NGINX Docker container found running"
    fi
    
    # Clean up PID file
    rm -f "$NGINX_PID"
    
    # Clean up any remaining nginx processes
    local remaining_pids=$(pgrep -f "nginx.*rtmp" 2>/dev/null || true)
    if [ -n "$remaining_pids" ]; then
        warning "Cleaning up remaining NGINX processes..."
        echo "$remaining_pids" | xargs kill -9 2>/dev/null || true
    fi
}

# Clean up transcoding processes
cleanup_transcoding_processes() {
    log "🧹 Cleaning up transcoding processes..."
    
    # Find and stop any FFmpeg transcoding processes
    local ffmpeg_pids=$(pgrep -f "ffmpeg.*transcode" 2>/dev/null || true)
    if [ -n "$ffmpeg_pids" ]; then
        warning "Stopping active FFmpeg transcoding processes..."
        echo "$ffmpeg_pids" | xargs kill -TERM 2>/dev/null || true
        
        # Wait a moment for graceful shutdown
        sleep 3
        
        # Force kill any remaining
        ffmpeg_pids=$(pgrep -f "ffmpeg.*transcode" 2>/dev/null || true)
        if [ -n "$ffmpeg_pids" ]; then
            warning "Force killing remaining FFmpeg processes..."
            echo "$ffmpeg_pids" | xargs kill -9 2>/dev/null || true
        fi
        
        success "✅ FFmpeg transcoding processes cleaned up"
    else
        log "No active FFmpeg transcoding processes found"
    fi
}

# Clean up HLS files
cleanup_hls_files() {
    if [ "$CLEAN_HLS" = true ]; then
        log "🗑️  Cleaning up HLS files..."
        
        if [ -d "$HLS_OUTPUT_DIR" ]; then
            # Remove all HLS files but preserve directory structure
            find "$HLS_OUTPUT_DIR" -name "*.ts" -delete 2>/dev/null || true
            find "$HLS_OUTPUT_DIR" -name "*.m3u8" -delete 2>/dev/null || true
            
            # Remove empty directories
            find "$HLS_OUTPUT_DIR" -type d -empty -delete 2>/dev/null || true
            
            success "✅ HLS files cleaned up"
        else
            log "HLS output directory not found"
        fi
    else
        log "Preserving HLS files (use --clean-hls to remove)"
    fi
}

# Clean up log files
cleanup_logs() {
    if [ "$PRESERVE_LOGS" = false ]; then
        log "🗑️  Cleaning up log files..."
        
        if [ -d "$LOGS_DIR" ]; then
            # Archive current logs before deletion
            local archive_name="logs_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            tar -czf "/tmp/$archive_name" -C "$PROJECT_ROOT" logs/ 2>/dev/null || true
            log "Logs archived to /tmp/$archive_name"
            
            # Remove log files
            rm -rf "$LOGS_DIR"/*
            success "✅ Log files cleaned up"
        fi
    else
        log "Preserving log files (use --clean-logs to remove)"
    fi
}

# Display final status
display_shutdown_status() {
    echo ""
    echo -e "${PURPLE}🛑 StreamForge Shutdown Complete${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""

    # Check if any services are still running
    local still_running=()

    if docker ps --format '{{.Names}}' | grep -q "streamforge-nginx"; then
        still_running+=("NGINX-RTMP (Docker)")
    fi

    if pgrep -f "transcoder.*8083" >/dev/null 2>&1; then
        still_running+=("Transcoder Service")
    fi

    if lsof -i :3000 >/dev/null 2>&1; then
        still_running+=("Web Server")
    fi

    if pgrep -f "ffmpeg.*transcode" >/dev/null 2>&1; then
        still_running+=("FFmpeg Processes")
    fi

    if [ ${#still_running[@]} -eq 0 ]; then
        success "✅ All services stopped successfully"
    else
        warning "⚠️  Some services may still be running:"
        for service in "${still_running[@]}"; do
            echo -e "   • ${YELLOW}$service${NC}"
        done
        echo ""
        echo -e "${YELLOW}💡 Manual cleanup commands:${NC}"
        echo -e "   • Kill remaining processes: ${CYAN}sudo pkill -f streamforge${NC}"
        echo -e "   • Stop Docker containers: ${CYAN}docker stop \$(docker ps -q --filter ancestor=streamforge-nginx)${NC}"
        echo -e "   • Check ports: ${CYAN}sudo netstat -tulpn | grep -E ':(1935|8080|8083|3000)'${NC}"
    fi

    echo ""
    echo -e "${GREEN}📋 Cleanup Summary:${NC}"

    if [ "$CLEAN_HLS" = true ]; then
        echo -e "   ✅ HLS files removed"
    else
        echo -e "   📁 HLS files preserved in $HLS_OUTPUT_DIR"
    fi

    if [ "$PRESERVE_LOGS" = false ]; then
        echo -e "   ✅ Log files cleaned up"
    else
        echo -e "   📝 Log files preserved in $LOGS_DIR"
        echo -e "       • Startup: ${CYAN}$LOGS_DIR/streamforge-startup.log${NC}"
        echo -e "       • Shutdown: ${CYAN}$LOGS_DIR/streamforge-shutdown.log${NC}"
        echo -e "       • Transcoding: ${CYAN}$LOGS_DIR/transcode_*.log${NC}"
    fi

    echo ""
    echo -e "${GREEN}🚀 To restart StreamForge:${NC}"
    echo -e "   ${CYAN}./start-streamforge.sh${NC}"
    echo ""
}

# Check if any StreamForge services are running
check_running_services() {
    log "🔍 Checking for running StreamForge services..."

    local found_services=false

    # Check Docker containers
    if docker ps --format '{{.Names}}' | grep -q "streamforge-nginx"; then
        log "Found running NGINX-RTMP Docker container"
        found_services=true
    fi

    # Check PID files
    if [ -f "$TRANSCODER_PID" ] && kill -0 "$(cat $TRANSCODER_PID)" 2>/dev/null; then
        log "Found running transcoder service"
        found_services=true
    fi

    if [ -f "$WEB_PID" ] && kill -0 "$(cat $WEB_PID)" 2>/dev/null; then
        log "Found running web server"
        found_services=true
    fi

    # Check for processes by name
    if pgrep -f "ffmpeg.*transcode" >/dev/null 2>&1; then
        log "Found running FFmpeg transcoding processes"
        found_services=true
    fi

    if [ "$found_services" = false ]; then
        warning "No running StreamForge services detected"
        echo -e "${YELLOW}💡 If you believe services are still running, try:${NC}"
        echo -e "   • Check processes: ${CYAN}ps aux | grep -E '(nginx|transcoder|ffmpeg)'${NC}"
        echo -e "   • Check ports: ${CYAN}sudo netstat -tulpn | grep -E ':(1935|8080|8083|3000)'${NC}"
        echo ""
        read -p "Continue with cleanup anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Shutdown cancelled by user"
            exit 0
        fi
    fi
}

# Main execution
main() {
    echo -e "${PURPLE}🛑 Stopping StreamForge Live Streaming Platform${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo ""

    # Initialize shutdown logging
    mkdir -p "$LOGS_DIR"
    echo "StreamForge shutdown initiated at $(date)" > "$LOGS_DIR/streamforge-shutdown.log"

    # Check what's running
    check_running_services

    echo ""
    log "🛑 Stopping services in reverse dependency order..."
    echo ""

    # Stop services in reverse order
    stop_web_server
    stop_transcoder_service
    stop_nginx_rtmp
    cleanup_transcoding_processes

    # Optional cleanup
    cleanup_hls_files
    cleanup_logs

    # Final status
    display_shutdown_status

    success "🎉 StreamForge shutdown completed!"
}

# Run main function
main "$@"
