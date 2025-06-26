#!/bin/bash

# StreamForge Health Check - Development Status Validator
# Version: 1.0 - Read-only health validation
# Description: Comprehensive health check without making changes

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              StreamForge Health Check Report                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}                  Read-Only Validation                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_status() {
    local service="$1"
    local status="$2"
    local details="${3:-}"
    
    case "$status" in
        "HEALTHY"|"RUNNING"|"ACTIVE")
            echo -e "  ${GREEN}✓${NC} ${WHITE}${service}${NC}: ${GREEN}${status}${NC} ${details}"
            ;;
        "UNHEALTHY"|"DOWN"|"FAILED"|"MISSING")
            echo -e "  ${RED}✗${NC} ${WHITE}${service}${NC}: ${RED}${status}${NC} ${details}"
            ;;
        "WARNING"|"PARTIAL")
            echo -e "  ${YELLOW}⚠${NC} ${WHITE}${service}${NC}: ${YELLOW}${status}${NC} ${details}"
            ;;
        *)
            echo -e "  ${BLUE}•${NC} ${WHITE}${service}${NC}: ${BLUE}${status}${NC} ${details}"
            ;;
    esac
}

check_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-3}"
    timeout "$timeout" bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1
}

check_http() {
    local url="$1"
    local timeout="${2:-5}"
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    echo "$response"
}

get_process_count() {
    local pattern="$1"
    pgrep -f "$pattern" 2>/dev/null | wc -l
}

get_docker_status() {
    local container_pattern="$1"
    local status=$(docker ps --filter "name=$container_pattern" --format "{{.Status}}" 2>/dev/null | head -1)
    if [[ -n "$status" ]]; then
        echo "$status"
    else
        echo "not running"
    fi
}

check_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

main() {
    print_header
    
    local healthy_services=0
    local total_services=0
    
    echo -e "${WHITE}🔍 Infrastructure Services${NC}"
    echo
    
    # Docker Engine
    total_services=$((total_services + 1))
    if docker info >/dev/null 2>&1; then
        print_status "Docker Engine" "RUNNING" "Version: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        healthy_services=$((healthy_services + 1))
    else
        print_status "Docker Engine" "DOWN" "Docker daemon not accessible"
    fi
    
    # PostgreSQL Database
    total_services=$((total_services + 1))
    if check_port "localhost" "5432"; then
        local docker_status=$(get_docker_status "postgres")
        print_status "PostgreSQL Database" "RUNNING" "Port 5432 open - $docker_status"
        healthy_services=$((healthy_services + 1))
    else
        print_status "PostgreSQL Database" "DOWN" "Port 5432 not accessible"
    fi
    
    # Redis Cache
    total_services=$((total_services + 1))
    if check_port "localhost" "6379"; then
        local docker_status=$(get_docker_status "redis")
        print_status "Redis Cache" "RUNNING" "Port 6379 open - $docker_status"
        healthy_services=$((healthy_services + 1))
    else
        print_status "Redis Cache" "DOWN" "Port 6379 not accessible"
    fi
    
    # NGINX RTMP Server
    total_services=$((total_services + 1))
    if check_port "localhost" "1935"; then
        local http_status="Unknown"
        if check_port "localhost" "8090"; then
            http_status="HTTP port 8090 also open"
        fi
        local docker_status=$(get_docker_status "nginx-rtmp")
        print_status "NGINX RTMP Server" "RUNNING" "RTMP port 1935 open - $http_status - $docker_status"
        healthy_services=$((healthy_services + 1))
    else
        print_status "NGINX RTMP Server" "DOWN" "Port 1935 not accessible"
    fi
    
    echo
    echo -e "${WHITE}🚀 Application Services${NC}"
    echo
    
    # Stream Transcoder
    total_services=$((total_services + 1))
    if check_port "localhost" "8082"; then
        local http_code=$(check_http "http://localhost:8082/health")
        local docker_status=$(get_docker_status "transcoder")
        if [[ "$http_code" == "200" ]]; then
            print_status "Stream Transcoder" "HEALTHY" "API responding (HTTP $http_code) - $docker_status"
        else
            print_status "Stream Transcoder" "PARTIAL" "Port open but API not responding (HTTP $http_code) - $docker_status"
        fi
        healthy_services=$((healthy_services + 1))
    else
        print_status "Stream Transcoder" "DOWN" "Port 8082 not accessible"
    fi
    
    # Stream Processing
    total_services=$((total_services + 1))
    if check_port "localhost" "8081"; then
        local http_code=$(check_http "http://localhost:8081/health")
        local docker_status=$(get_docker_status "stream-processing")
        if [[ "$http_code" == "200" ]]; then
            print_status "Stream Processing" "HEALTHY" "API responding (HTTP $http_code) - $docker_status"
        else
            print_status "Stream Processing" "PARTIAL" "Port open but API not responding (HTTP $http_code) - $docker_status"
        fi
        healthy_services=$((healthy_services + 1))
    else
        print_status "Stream Processing" "DOWN" "Port 8081 not accessible"
    fi
    
    # User Management
    total_services=$((total_services + 1))
    if check_port "localhost" "8083"; then
        local http_code=$(check_http "http://localhost:8083/health")
        local docker_status=$(get_docker_status "user-management")
        if [[ "$http_code" == "200" ]]; then
            print_status "User Management" "HEALTHY" "API responding (HTTP $http_code) - $docker_status"
        else
            print_status "User Management" "PARTIAL" "Port open but API not responding (HTTP $http_code) - $docker_status"
        fi
        healthy_services=$((healthy_services + 1))
    else
        print_status "User Management" "DOWN" "Port 8083 not accessible"
    fi
    
    # Web Player
    total_services=$((total_services + 1))
    if check_port "localhost" "3000"; then
        local http_code=$(check_http "http://localhost:3000")
        local docker_status=$(get_docker_status "web-player")
        local python_count=$(get_process_count "python3.*http.server.*3000")
        
        if [[ "$http_code" == "200" ]]; then
            if [[ "$python_count" -gt 0 ]]; then
                print_status "Web Player" "RUNNING" "Python HTTP server active (HTTP $http_code)"
            else
                print_status "Web Player" "RUNNING" "Docker container active (HTTP $http_code) - $docker_status"
            fi
        else
            print_status "Web Player" "PARTIAL" "Port open but not responding (HTTP $http_code)"
        fi
        healthy_services=$((healthy_services + 1))
    else
        print_status "Web Player" "DOWN" "Port 3000 not accessible"
    fi
    
    echo
    echo -e "${WHITE}🐍 Python Services${NC}"
    echo
    
    # CORS/HLS Server
    total_services=$((total_services + 1))
    local cors_process_count=$(get_process_count "cors_server.py")
    if [[ "$cors_process_count" -gt 0 ]] && check_port "localhost" "8085"; then
        local http_code=$(check_http "http://localhost:8085")
        print_status "CORS/HLS Server" "RUNNING" "Process active, port 8085 open (HTTP $http_code)"
        healthy_services=$((healthy_services + 1))
    elif [[ "$cors_process_count" -gt 0 ]]; then
        print_status "CORS/HLS Server" "PARTIAL" "Process running but port 8085 not accessible"
    elif check_port "localhost" "8085"; then
        print_status "CORS/HLS Server" "PARTIAL" "Port 8085 open but cors_server.py process not found"
    else
        print_status "CORS/HLS Server" "DOWN" "Process not running and port not accessible"
    fi
    
    # Live Transcoder
    total_services=$((total_services + 1))
    local transcoder_process_count=$(get_process_count "live_transcoder.py")
    local ffmpeg_stream1_count=$(get_process_count "ffmpeg.*stream1")
    local ffmpeg_stream3_count=$(get_process_count "ffmpeg.*stream3")
    
    if [[ "$transcoder_process_count" -gt 0 ]] && [[ "$ffmpeg_stream1_count" -gt 0 ]] && [[ "$ffmpeg_stream3_count" -gt 0 ]]; then
        print_status "Live Transcoder" "ACTIVE" "Controller + FFmpeg processes for stream1 & stream3 running"
        healthy_services=$((healthy_services + 1))
    elif [[ "$transcoder_process_count" -gt 0 ]]; then
        local ffmpeg_total=$((ffmpeg_stream1_count + ffmpeg_stream3_count))
        print_status "Live Transcoder" "PARTIAL" "Controller running but only $ffmpeg_total/2 FFmpeg processes active"
    else
        print_status "Live Transcoder" "DOWN" "No live_transcoder.py process found"
    fi
    
    echo
    echo -e "${WHITE}📺 Streaming Content${NC}"
    echo
    
    # Stream1 HLS
    total_services=$((total_services + 1))
    local stream1_playlist="/tmp/hls_shared/stream1/playlist.m3u8"
    local stream1_size=$(check_file_size "$stream1_playlist")
    if [[ "$stream1_size" -gt 0 ]]; then
        local segment_count=$(ls /tmp/hls_shared/stream1/segment_*.ts 2>/dev/null | wc -l || echo "0")
        print_status "Stream1 HLS Content" "ACTIVE" "Playlist: ${stream1_size} bytes, Segments: $segment_count"
        healthy_services=$((healthy_services + 1))
    elif [[ -f "$stream1_playlist" ]]; then
        print_status "Stream1 HLS Content" "WARNING" "Empty playlist file exists"
    else
        print_status "Stream1 HLS Content" "MISSING" "No playlist found at $stream1_playlist"
    fi
    
    # Stream3 HLS
    total_services=$((total_services + 1))
    local stream3_playlist="/tmp/hls_shared/stream3/playlist.m3u8"
    local stream3_size=$(check_file_size "$stream3_playlist")
    if [[ "$stream3_size" -gt 0 ]]; then
        local segment_count=$(ls /tmp/hls_shared/stream3/segment_*.ts 2>/dev/null | wc -l || echo "0")
        print_status "Stream3 HLS Content" "ACTIVE" "Playlist: ${stream3_size} bytes, Segments: $segment_count"
        healthy_services=$((healthy_services + 1))
    elif [[ -f "$stream3_playlist" ]]; then
        print_status "Stream3 HLS Content" "WARNING" "Empty playlist file exists"
    else
        print_status "Stream3 HLS Content" "MISSING" "No playlist found at $stream3_playlist"
    fi
    
    echo
    echo -e "${WHITE}🌐 Endpoint Accessibility${NC}"
    echo
    
    # Web Player Test Page
    total_services=$((total_services + 1))
    local web_test_page="http://localhost:3000/test-player.html"
    local web_test_code=$(check_http "$web_test_page")
    if [[ "$web_test_code" == "200" ]]; then
        print_status "Web Test Player" "ACCESSIBLE" "$web_test_page"
        healthy_services=$((healthy_services + 1))
    else
        print_status "Web Test Player" "FAILED" "$web_test_page (HTTP $web_test_code)"
    fi
    
    # HLS Stream1 Endpoint
    total_services=$((total_services + 1))
    local hls1_url="http://localhost:8085/stream1/playlist.m3u8"
    local hls1_code=$(check_http "$hls1_url")
    if [[ "$hls1_code" == "200" ]]; then
        print_status "HLS Stream1 Endpoint" "ACCESSIBLE" "$hls1_url"
        healthy_services=$((healthy_services + 1))
    else
        print_status "HLS Stream1 Endpoint" "FAILED" "$hls1_url (HTTP $hls1_code)"
    fi
    
    # HLS Stream3 Endpoint
    total_services=$((total_services + 1))
    local hls3_url="http://localhost:8085/stream3/playlist.m3u8"
    local hls3_code=$(check_http "$hls3_url")
    if [[ "$hls3_code" == "200" ]]; then
        print_status "HLS Stream3 Endpoint" "ACCESSIBLE" "$hls3_url"
        healthy_services=$((healthy_services + 1))
    else
        print_status "HLS Stream3 Endpoint" "FAILED" "$hls3_url (HTTP $hls3_code)"
    fi
    
    # NGINX Stats
    total_services=$((total_services + 1))
    local nginx_stats="http://localhost:8090/stat"
    local nginx_stats_code=$(check_http "$nginx_stats")
    if [[ "$nginx_stats_code" == "200" ]]; then
        print_status "NGINX RTMP Stats" "ACCESSIBLE" "$nginx_stats"
        healthy_services=$((healthy_services + 1))
    else
        print_status "NGINX RTMP Stats" "FAILED" "$nginx_stats (HTTP $nginx_stats_code)"
    fi
    
    # Final Summary
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      HEALTH SUMMARY                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local health_percentage=$((healthy_services * 100 / total_services))
    
    echo -e "${WHITE}📊 Overall Health: ${healthy_services}/${total_services} services (${health_percentage}%)${NC}"
    echo
    
    if [[ "$health_percentage" -ge 90 ]]; then
        echo -e "${GREEN}🎉 Excellent! StreamForge platform is fully operational${NC}"
        echo -e "${WHITE}🚀 Ready for live streaming production workloads${NC}"
    elif [[ "$health_percentage" -ge 75 ]]; then
        echo -e "${YELLOW}⚠️  Good - Most services are running with minor issues${NC}"
        echo -e "${WHITE}🔧 Some optimization may be needed for full functionality${NC}"
    elif [[ "$health_percentage" -ge 50 ]]; then
        echo -e "${YELLOW}🚧 Partial - Core services running but significant issues detected${NC}"
        echo -e "${WHITE}🛠️  Manual intervention required for full functionality${NC}"
    else
        echo -e "${RED}🚨 Critical - Multiple service failures detected${NC}"
        echo -e "${WHITE}🆘 Platform requires immediate attention${NC}"
    fi
    
    echo
    echo -e "${WHITE}💡 Quick Actions:${NC}"
    if [[ "$health_percentage" -lt 100 ]]; then
        echo -e "  • Run: ${BLUE}./streamforge-quick-start.sh${NC} to auto-fix issues"
        echo -e "  • Check: ${BLUE}docker-compose logs${NC} for detailed error information"
        echo -e "  • Monitor: ${BLUE}docker ps${NC} to see container status"
    fi
    echo -e "  • Web Player: ${BLUE}http://localhost:3000/test-player.html${NC}"
    echo -e "  • RTMP Stream: ${BLUE}rtmp://localhost:1935/live/stream1${NC}"
    
    # Return appropriate exit code
    if [[ "$health_percentage" -ge 75 ]]; then
        return 0
    else
        return 1
    fi
}

main "$@" 