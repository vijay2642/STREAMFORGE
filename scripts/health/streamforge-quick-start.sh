#!/bin/bash

# StreamForge Quick Start - Simplified Health Check & Startup
# Version: 1.0 - Optimized for Current Architecture
# Description: Quick startup script for the existing StreamForge setup

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/streamforge-quickstart.log"

# Initialize log
echo "StreamForge Quick Start - $(date)" > "$LOG_FILE"

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                StreamForge Quick Start                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}              Health Check & Auto Startup                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_info() {
    echo "$(date '+%H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE"
}

print_status() {
    local service="$1"
    local status="$2"
    local message="${3:-}"
    
    case "$status" in
        "HEALTHY"|"RUNNING")
            echo -e "  ${GREEN}✓${NC} ${WHITE}${service}${NC}: ${GREEN}${status}${NC} ${message}"
            ;;
        "FAILED"|"DOWN")
            echo -e "  ${RED}✗${NC} ${WHITE}${service}${NC}: ${RED}${status}${NC} ${message}"
            ;;
        "STARTING")
            echo -e "  ${YELLOW}⚡${NC} ${WHITE}${service}${NC}: ${YELLOW}${status}${NC} ${message}"
            ;;
        *)
            echo -e "  ${BLUE}•${NC} ${WHITE}${service}${NC}: ${BLUE}${status}${NC} ${message}"
            ;;
    esac
}

check_port() {
    local port="$1"
    local timeout="${2:-3}"
    timeout "$timeout" bash -c "</dev/tcp/localhost/$port" >/dev/null 2>&1
}

check_process() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

check_docker_container() {
    local container_name="$1"
    docker ps --filter "name=$container_name" --filter "status=running" --quiet 2>/dev/null | grep -q .
}

start_docker_services() {
    log_info "Starting Docker infrastructure services..."
    cd "$SCRIPT_DIR"
    
    # Start core infrastructure first
    docker-compose up -d postgres redis nginx-rtmp >/dev/null 2>&1 || true
    
    # Wait a moment for infrastructure to stabilize
    sleep 5
    
    # Start application services
    docker-compose up -d transcoder stream-processing user-management web-player >/dev/null 2>&1 || true
    
    # Give services time to start
    sleep 10
}

start_python_service() {
    local script="$1"
    local description="$2"
    
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        log_info "Starting $description..."
        cd "$SCRIPT_DIR"
        
        if [[ "$script" == "live_transcoder.py"* ]]; then
            nohup python3 live_transcoder.py both >/dev/null 2>&1 &
        else
            nohup python3 "$script" >/dev/null 2>&1 &
        fi
        
        sleep 3
        return 0
    else
        log_error "Script not found: $script"
        return 1
    fi
}

check_and_start_service() {
    local service_name="$1"
    local check_method="$2"
    local check_param="$3"
    local start_method="$4"
    local start_param="${5:-}"
    
    case "$check_method" in
        "port")
            if check_port "$check_param"; then
                print_status "$service_name" "RUNNING" "Port $check_param responsive"
                return 0
            fi
            ;;
        "process")
            if check_process "$check_param"; then
                print_status "$service_name" "RUNNING" "Process active"
                return 0
            fi
            ;;
        "docker")
            if check_docker_container "$check_param"; then
                print_status "$service_name" "RUNNING" "Container active"
                return 0
            fi
            ;;
        "combined")
            if check_process "$check_param" && check_port "8085"; then
                print_status "$service_name" "RUNNING" "Service active"
                return 0
            fi
            ;;
        "transcoder")
            if check_process "live_transcoder.py" && check_process "ffmpeg.*stream1" && check_process "ffmpeg.*stream3"; then
                print_status "$service_name" "RUNNING" "All processes active"
                return 0
            fi
            ;;
    esac
    
    # Service not running, try to start it
    print_status "$service_name" "STARTING" "Service not detected, starting..."
    
    case "$start_method" in
        "docker")
            # Docker services are started in bulk
            return 0
            ;;
        "python")
            if start_python_service "$start_param" "$service_name"; then
                sleep 5
                # Re-check the service
                case "$check_method" in
                    "combined")
                        if check_process "$check_param" && check_port "8085"; then
                            print_status "$service_name" "HEALTHY" "Started successfully"
                            return 0
                        fi
                        ;;
                    "transcoder")
                        if check_process "live_transcoder.py"; then
                            print_status "$service_name" "HEALTHY" "Started successfully"
                            return 0
                        fi
                        ;;
                    "process")
                        if check_process "$check_param"; then
                            print_status "$service_name" "HEALTHY" "Started successfully"
                            return 0
                        fi
                        ;;
                esac
            fi
            ;;
    esac
    
    print_status "$service_name" "FAILED" "Could not start"
    return 1
}

main() {
    print_header
    
    log_info "Starting StreamForge platform health check and auto-startup"
    
    echo -e "${WHITE}🔍 Checking and starting services...${NC}"
    echo
    
    # Track overall success
    local overall_success=true
    
    # Start Docker services first (bulk operation)
    echo -e "${BLUE}📦 Docker Infrastructure Services${NC}"
    start_docker_services
    
    # Wait for Docker services to stabilize
    sleep 15
    
    # Check Docker services
    if ! check_and_start_service "PostgreSQL Database" "port" "5432" "docker" "postgres"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "Redis Cache" "port" "6379" "docker" "redis"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "NGINX RTMP Server" "port" "1935" "docker" "nginx-rtmp"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "Stream Transcoder" "port" "8082" "docker" "transcoder"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "Stream Processing" "port" "8081" "docker" "stream-processing"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "User Management" "port" "8083" "docker" "user-management"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "Web Player" "port" "3000" "docker" "web-player"; then
        overall_success=false
    fi
    
    echo
    echo -e "${BLUE}🐍 Python Standalone Services${NC}"
    
    if ! check_and_start_service "CORS/HLS Server" "combined" "cors_server.py" "python" "cors_server.py"; then
        overall_success=false
    fi
    
    if ! check_and_start_service "Live Transcoder" "transcoder" "live_transcoder.py" "python" "live_transcoder.py"; then
        overall_success=false
    fi
    
    # Additional health checks
    echo
    echo -e "${BLUE}🔍 Additional Health Checks${NC}"
    
    # Check if HLS directories exist and have content
    if [[ -d "/tmp/hls_shared/stream1" ]] && [[ -f "/tmp/hls_shared/stream1/playlist.m3u8" ]]; then
        local playlist_size=$(stat -f%z "/tmp/hls_shared/stream1/playlist.m3u8" 2>/dev/null || stat -c%s "/tmp/hls_shared/stream1/playlist.m3u8" 2>/dev/null || echo "0")
        if [[ "$playlist_size" -gt 0 ]]; then
            print_status "Stream1 HLS Playlist" "HEALTHY" "Playlist active ($playlist_size bytes)"
        else
            print_status "Stream1 HLS Playlist" "FAILED" "Empty playlist"
            overall_success=false
        fi
    else
        print_status "Stream1 HLS Playlist" "FAILED" "Playlist not found"
        overall_success=false
    fi
    
    if [[ -d "/tmp/hls_shared/stream3" ]] && [[ -f "/tmp/hls_shared/stream3/playlist.m3u8" ]]; then
        local playlist_size=$(stat -f%z "/tmp/hls_shared/stream3/playlist.m3u8" 2>/dev/null || stat -c%s "/tmp/hls_shared/stream3/playlist.m3u8" 2>/dev/null || echo "0")
        if [[ "$playlist_size" -gt 0 ]]; then
            print_status "Stream3 HLS Playlist" "HEALTHY" "Playlist active ($playlist_size bytes)"
        else
            print_status "Stream3 HLS Playlist" "FAILED" "Empty playlist"
            overall_success=false
        fi
    else
        print_status "Stream3 HLS Playlist" "FAILED" "Playlist not found"
        overall_success=false
    fi
    
    # Final status report
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        QUICK START REPORT                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ "$overall_success" == "true" ]]; then
        echo -e "${GREEN}✅ StreamForge Platform is READY!${NC}"
        echo
        echo -e "${WHITE}🚀 Live Streaming Endpoints:${NC}"
        echo -e "  • ${GREEN}Web Player:${NC}       ${BLUE}http://localhost:3000/test-player.html${NC}"
        echo -e "  • ${GREEN}CORS/HLS Server:${NC}  ${BLUE}http://localhost:8085${NC}"
        echo -e "  • ${GREEN}RTMP Ingestion:${NC}   ${BLUE}rtmp://localhost:1935/live/stream1${NC}"
        echo -e "  • ${GREEN}Stream1 HLS:${NC}      ${BLUE}http://localhost:8085/stream1/playlist.m3u8${NC}"
        echo -e "  • ${GREEN}Stream3 HLS:${NC}      ${BLUE}http://localhost:8085/stream3/playlist.m3u8${NC}"
        echo
        echo -e "${WHITE}📊 Management Endpoints:${NC}"
        echo -e "  • ${GREEN}Transcoder API:${NC}   ${BLUE}http://localhost:8082${NC}"
        echo -e "  • ${GREEN}Stream Processing:${NC} ${BLUE}http://localhost:8081${NC}"
        echo -e "  • ${GREEN}User Management:${NC}  ${BLUE}http://localhost:8083${NC}"
        echo -e "  • ${GREEN}NGINX Stats:${NC}      ${BLUE}http://localhost:8090/stat${NC}"
        echo
        echo -e "${YELLOW}🎬 Ready to stream! Send RTMP to: rtmp://localhost:1935/live/stream1${NC}"
        
        return 0
    else
        echo -e "${RED}❌ Some services failed to start properly${NC}"
        echo -e "${WHITE}💡 Check log file: ${BLUE}$LOG_FILE${NC}"
        echo -e "${WHITE}💡 Try running: ${BLUE}docker-compose logs${NC} ${WHITE}for more details${NC}"
        
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Quick start script completed"
}

trap cleanup EXIT

# Run main function
main "$@" 