#!/bin/bash

# StreamForge Live Streaming Platform - Health Check & Startup Script
# Author: StreamForge Team
# Version: 1.0
# Description: Comprehensive health check and intelligent startup for all platform services

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/streamforge-startup.log"
readonly TIMEOUT_STARTUP=30
readonly TIMEOUT_HEALTH=10
readonly MAX_RETRIES=3

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Service definitions with their health check endpoints and dependencies
declare -A SERVICES=(
    ["postgres"]="Database"
    ["redis"]="Cache Store"
    ["nginx-rtmp"]="RTMP Ingestion Server"
    ["transcoder"]="Stream Transcoder"
    ["stream-processing"]="Stream Processing"
    ["user-management"]="User Management"
    ["web-player"]="Web Player"
    ["cors-server"]="CORS/HLS Server"
    ["live-transcoder"]="Live Transcoder"
)

declare -A SERVICE_PORTS=(
    ["postgres"]="5432"
    ["redis"]="6379"
    ["nginx-rtmp"]="1935"
    ["nginx-http"]="8090"
    ["transcoder"]="8082"
    ["stream-processing"]="8081"
    ["user-management"]="8083"
    ["web-player"]="3000"
    ["cors-server"]="8085"
)

declare -A SERVICE_HEALTH_URLS=(
    ["postgres"]="localhost:5432"
    ["redis"]="localhost:6379"
    ["nginx-rtmp"]="localhost:1935"
    ["nginx-http"]="http://localhost:8090/stat"
    ["transcoder"]="http://localhost:8082/health"
    ["stream-processing"]="http://localhost:8081/health"
    ["user-management"]="http://localhost:8083/health"
    ["web-player"]="http://localhost:3000"
    ["cors-server"]="http://localhost:8085"
)

declare -A SERVICE_DEPENDENCIES=(
    ["redis"]=""
    ["postgres"]=""
    ["nginx-rtmp"]=""
    ["transcoder"]="postgres nginx-rtmp"
    ["stream-processing"]="postgres"
    ["user-management"]="postgres"
    ["web-player"]=""
    ["cors-server"]=""
    ["live-transcoder"]="nginx-rtmp cors-server"
)

# Global status tracking
declare -A SERVICE_STATUS=()
declare -A SERVICE_ERRORS=()
OVERALL_SUCCESS=true

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Display functions
print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              StreamForge Health Check & Startup              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}                     Version 1.0                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_status() {
    local service="$1"
    local status="$2"
    local message="${3:-}"
    
    case "$status" in
        "HEALTHY")
            echo -e "  ${GREEN}✓${NC} ${WHITE}${service}${NC}: ${GREEN}${status}${NC} ${message}"
            ;;
        "UNHEALTHY"|"DOWN"|"FAILED")
            echo -e "  ${RED}✗${NC} ${WHITE}${service}${NC}: ${RED}${status}${NC} ${message}"
            ;;
        "STARTING")
            echo -e "  ${YELLOW}⚡${NC} ${WHITE}${service}${NC}: ${YELLOW}${status}${NC} ${message}"
            ;;
        "SKIPPED")
            echo -e "  ${BLUE}→${NC} ${WHITE}${service}${NC}: ${BLUE}${status}${NC} ${message}"
            ;;
        *)
            echo -e "  ${PURPLE}?${NC} ${WHITE}${service}${NC}: ${PURPLE}${status}${NC} ${message}"
            ;;
    esac
}

# Network utility functions
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    timeout "$timeout" bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1
}

check_http_endpoint() {
    local url="$1"
    local timeout="${2:-10}"
    local expected_code="${3:-200}"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        return 0
    else
        return 1
    fi
}

# Docker utility functions
is_docker_running() {
    docker info >/dev/null 2>&1
}

get_docker_container_status() {
    local container_name="$1"
    docker ps --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null || echo "not found"
}

start_docker_service() {
    local service_name="$1"
    log_info "Starting Docker service: $service_name"
    
    if cd "$SCRIPT_DIR" && docker-compose up -d "$service_name" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Process utility functions
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

start_python_service() {
    local script_name="$1"
    local service_description="$2"
    
    log_info "Starting Python service: $service_description"
    
    if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
        cd "$SCRIPT_DIR"
        nohup python3 "$script_name" >/dev/null 2>&1 &
        return 0
    else
        log_error "Script not found: $script_name"
        return 1
    fi
}

# Service-specific health check functions
check_postgres_health() {
    if check_port "localhost" "5432" 3; then
        # Try to connect to PostgreSQL
        if command -v psql >/dev/null 2>&1; then
            PGPASSWORD=streamforge123 psql -h localhost -U streamforge -d streamforge -c "SELECT 1;" >/dev/null 2>&1
        else
            # If psql not available, just check port
            return 0
        fi
    else
        return 1
    fi
}

check_redis_health() {
    if check_port "localhost" "6379" 3; then
        if command -v redis-cli >/dev/null 2>&1; then
            redis-cli -h localhost ping >/dev/null 2>&1
        else
            return 0
        fi
    else
        return 1
    fi
}

check_nginx_rtmp_health() {
    check_port "localhost" "1935" 3 && check_port "localhost" "8090" 3
}

check_transcoder_health() {
    check_http_endpoint "http://localhost:8082/health" 5 || check_port "localhost" "8082" 3
}

check_stream_processing_health() {
    check_http_endpoint "http://localhost:8081/health" 5 || check_port "localhost" "8081" 3
}

check_user_management_health() {
    check_http_endpoint "http://localhost:8083/health" 5 || check_port "localhost" "8083" 3
}

check_web_player_health() {
    check_http_endpoint "http://localhost:3000" 5
}

check_cors_server_health() {
    check_http_endpoint "http://localhost:8085" 5 && is_process_running "cors_server.py"
}

check_live_transcoder_health() {
    is_process_running "live_transcoder.py" && is_process_running "ffmpeg.*stream1" && is_process_running "ffmpeg.*stream3"
}

# Generic health check dispatcher
check_service_health() {
    local service="$1"
    
    case "$service" in
        "postgres") check_postgres_health ;;
        "redis") check_redis_health ;;
        "nginx-rtmp") check_nginx_rtmp_health ;;
        "transcoder") check_transcoder_health ;;
        "stream-processing") check_stream_processing_health ;;
        "user-management") check_user_management_health ;;
        "web-player") check_web_player_health ;;
        "cors-server") check_cors_server_health ;;
        "live-transcoder") check_live_transcoder_health ;;
        *) 
            log_warn "Unknown service health check: $service"
            return 1
            ;;
    esac
}

# Service startup functions
start_postgres() {
    start_docker_service "postgres"
}

start_redis() {
    start_docker_service "redis"
}

start_nginx_rtmp() {
    start_docker_service "nginx-rtmp"
}

start_transcoder() {
    start_docker_service "transcoder"
}

start_stream_processing() {
    start_docker_service "stream-processing"
}

start_user_management() {
    start_docker_service "user-management"
}

start_web_player() {
    start_docker_service "web-player"
}

start_cors_server() {
    if ! is_process_running "cors_server.py"; then
        start_python_service "cors_server.py" "CORS/HLS Server"
    else
        return 0
    fi
}

start_live_transcoder() {
    if ! is_process_running "live_transcoder.py"; then
        start_python_service "live_transcoder.py both" "Live Transcoder"
    else
        return 0
    fi
}

# Generic service starter dispatcher
start_service() {
    local service="$1"
    
    case "$service" in
        "postgres") start_postgres ;;
        "redis") start_redis ;;
        "nginx-rtmp") start_nginx_rtmp ;;
        "transcoder") start_transcoder ;;
        "stream-processing") start_stream_processing ;;
        "user-management") start_user_management ;;
        "web-player") start_web_player ;;
        "cors-server") start_cors_server ;;
        "live-transcoder") start_live_transcoder ;;
        *)
            log_warn "Unknown service startup: $service"
            return 1
            ;;
    esac
}

# Dependency checking
check_dependencies() {
    local service="$1"
    local deps="${SERVICE_DEPENDENCIES[$service]}"
    
    if [[ -z "$deps" ]]; then
        return 0
    fi
    
    for dep in $deps; do
        if [[ "${SERVICE_STATUS[$dep]:-}" != "HEALTHY" ]]; then
            log_warn "Dependency $dep is not healthy for service $service"
            return 1
        fi
    done
    
    return 0
}

# Wait for service to become healthy
wait_for_service_health() {
    local service="$1"
    local timeout="$2"
    local interval=2
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if check_service_health "$service"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Main health check and startup logic
process_service() {
    local service="$1"
    local description="${SERVICES[$service]}"
    
    print_status "$description" "CHECKING" "Performing health check..."
    
    # Check if service is already healthy
    if check_service_health "$service"; then
        SERVICE_STATUS["$service"]="HEALTHY"
        print_status "$description" "HEALTHY" "Already running and responsive"
        return 0
    fi
    
    # Check dependencies
    if ! check_dependencies "$service"; then
        SERVICE_STATUS["$service"]="FAILED"
        SERVICE_ERRORS["$service"]="Dependencies not met"
        print_status "$description" "FAILED" "Dependencies not healthy"
        OVERALL_SUCCESS=false
        return 1
    fi
    
    # Try to start the service
    print_status "$description" "STARTING" "Attempting to start service..."
    
    local retry_count=0
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        if start_service "$service"; then
            # Wait for service to become healthy
            if wait_for_service_health "$service" "$TIMEOUT_STARTUP"; then
                SERVICE_STATUS["$service"]="HEALTHY"
                print_status "$description" "HEALTHY" "Started successfully"
                return 0
            else
                retry_count=$((retry_count + 1))
                if [[ $retry_count -lt $MAX_RETRIES ]]; then
                    print_status "$description" "RETRYING" "Attempt $retry_count failed, retrying..."
                    sleep 5
                fi
            fi
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                print_status "$description" "RETRYING" "Start failed, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    # Service failed to start after all retries
    SERVICE_STATUS["$service"]="FAILED"
    SERVICE_ERRORS["$service"]="Failed to start after $MAX_RETRIES attempts"
    print_status "$description" "FAILED" "Could not start after $MAX_RETRIES attempts"
    OVERALL_SUCCESS=false
    return 1
}

# Final status report
print_final_report() {
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        FINAL STATUS REPORT                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Service status summary
    echo -e "${WHITE}📊 Service Status Summary:${NC}"
    echo
    
    local healthy_count=0
    local total_count=0
    
    for service in "${!SERVICES[@]}"; do
        local description="${SERVICES[$service]}"
        local status="${SERVICE_STATUS[$service]:-UNKNOWN}"
        local error="${SERVICE_ERRORS[$service]:-}"
        
        total_count=$((total_count + 1))
        
        case "$status" in
            "HEALTHY")
                print_status "$description" "$status"
                healthy_count=$((healthy_count + 1))
                ;;
            *)
                print_status "$description" "$status" "$error"
                ;;
        esac
    done
    
    echo
    echo -e "${WHITE}🌐 Service Endpoints:${NC}"
    echo
    
    # List accessible endpoints
    for service in "${!SERVICE_PORTS[@]}"; do
        local port="${SERVICE_PORTS[$service]}"
        local status="${SERVICE_STATUS[$service]:-UNKNOWN}"
        
        if [[ "$status" == "HEALTHY" ]]; then
            case "$service" in
                "web-player")
                    echo -e "  ${GREEN}🌍${NC} Web Player:           ${BLUE}http://localhost:$port${NC}"
                    ;;
                "cors-server")
                    echo -e "  ${GREEN}📡${NC} HLS/CORS Server:      ${BLUE}http://localhost:$port${NC}"
                    ;;
                "nginx-rtmp")
                    echo -e "  ${GREEN}📺${NC} RTMP Ingestion:       ${BLUE}rtmp://localhost:$port/live${NC}"
                    ;;
                "nginx-http")
                    echo -e "  ${GREEN}📊${NC} NGINX Stats:          ${BLUE}http://localhost:$port/stat${NC}"
                    ;;
                "transcoder")
                    echo -e "  ${GREEN}⚙️${NC} Transcoder API:       ${BLUE}http://localhost:$port${NC}"
                    ;;
                "stream-processing")
                    echo -e "  ${GREEN}🔄${NC} Stream Processing:    ${BLUE}http://localhost:$port${NC}"
                    ;;
                "user-management")
                    echo -e "  ${GREEN}👤${NC} User Management:      ${BLUE}http://localhost:$port${NC}"
                    ;;
            esac
        fi
    done
    
    echo
    echo -e "${WHITE}📈 Overall Health: ${healthy_count}/${total_count} services healthy${NC}"
    
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        echo -e "${GREEN}✅ StreamForge platform is fully operational!${NC}"
        echo
        echo -e "${WHITE}🚀 Ready for live streaming:${NC}"
        echo -e "  • Stream to: ${BLUE}rtmp://localhost:1935/live/stream1${NC}"
        echo -e "  • Watch at:  ${BLUE}http://localhost:3000/test-player.html${NC}"
        echo -e "  • HLS URLs:  ${BLUE}http://localhost:8085/stream1/playlist.m3u8${NC}"
        return 0
    else
        echo -e "${RED}❌ Some services failed to start. Check logs for details.${NC}"
        echo -e "${WHITE}💡 Log file: ${BLUE}$LOG_FILE${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Health check and startup script completed"
}

# Main execution
main() {
    # Initialize log file
    echo "StreamForge Health Check and Startup - $(date)" > "$LOG_FILE"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Print header
    print_header
    
    log_info "Starting StreamForge health check and startup sequence"
    
    # Check Docker availability
    if ! is_docker_running; then
        echo -e "${RED}❌ Docker is not running! Please start Docker first.${NC}"
        exit 1
    fi
    
    echo -e "${WHITE}🔍 Performing comprehensive health checks...${NC}"
    echo
    
    # Define service startup order (respecting dependencies)
    local service_order=(
        "postgres"
        "redis"
        "nginx-rtmp"
        "transcoder"
        "stream-processing"
        "user-management"
        "web-player"
        "cors-server"
        "live-transcoder"
    )
    
    # Process each service in order
    for service in "${service_order[@]}"; do
        if [[ -n "${SERVICES[$service]:-}" ]]; then
            process_service "$service"
            sleep 2  # Brief pause between services
        fi
    done
    
    # Print final report
    print_final_report
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 