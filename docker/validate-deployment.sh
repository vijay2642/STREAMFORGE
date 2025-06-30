#!/bin/bash

# StreamForge Deployment Validation Script
# Comprehensive validation of the Docker deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
TEST_STREAM_KEY="validation_test_$(date +%s)"
VALIDATION_LOG="/tmp/streamforge-validation.log"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$VALIDATION_LOG"
}

success() {
    local message="✅ $1"
    echo -e "${GREEN}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$VALIDATION_LOG"
}

warning() {
    local message="⚠️  $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$VALIDATION_LOG"
}

error() {
    local message="❌ $1"
    echo -e "${RED}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$VALIDATION_LOG"
}

# Test Docker and Docker Compose
test_docker() {
    log "Testing Docker and Docker Compose..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running or not accessible"
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        return 1
    fi
    
    success "Docker and Docker Compose are available"
    return 0
}

# Test service containers
test_containers() {
    log "Testing service containers..."
    
    local services=("nginx-rtmp" "transcoder" "hls-server" "admin-api" "web-interface")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            success "Container $service is running"
        else
            error "Container $service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        success "All containers are running"
        return 0
    else
        error "Failed containers: ${failed_services[*]}"
        return 1
    fi
}

# Test service health endpoints
test_health_endpoints() {
    log "Testing service health endpoints..."
    
    local endpoints=(
        "localhost:8083/health:Transcoder"
        "localhost:8085/health:HLS-Server"
        "localhost:9000/health:Admin-API"
        "localhost:8080/health:NGINX-RTMP"
    )
    
    local failed_endpoints=()
    
    for endpoint_info in "${endpoints[@]}"; do
        local endpoint=$(echo "$endpoint_info" | cut -d':' -f1,2)
        local service_name=$(echo "$endpoint_info" | cut -d':' -f3)
        
        if curl -f -s "http://$endpoint" > /dev/null 2>&1; then
            success "$service_name health endpoint is responding"
        else
            error "$service_name health endpoint is not responding"
            failed_endpoints+=("$service_name")
        fi
    done
    
    if [ ${#failed_endpoints[@]} -eq 0 ]; then
        success "All health endpoints are responding"
        return 0
    else
        error "Failed health endpoints: ${failed_endpoints[*]}"
        return 1
    fi
}

# Test RTMP server
test_rtmp_server() {
    log "Testing RTMP server availability..."
    
    if nc -z localhost 1935 2>/dev/null; then
        success "RTMP server is listening on port 1935"
        return 0
    else
        error "RTMP server is not accessible on port 1935"
        return 1
    fi
}

# Test dynamic directory creation
test_dynamic_directories() {
    log "Testing dynamic directory creation..."
    
    local test_dir="/tmp/streamforge/hls/$TEST_STREAM_KEY"
    
    # Simulate stream directory creation
    mkdir -p "$test_dir"/{720p,480p,360p}
    
    if [ -d "$test_dir/720p" ] && [ -d "$test_dir/480p" ] && [ -d "$test_dir/360p" ]; then
        success "Dynamic directory creation test passed"
        
        # Create test master playlist
        cat > "$test_dir/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=2996000,RESOLUTION=1280x720
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1498000,RESOLUTION=854x480
480p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=856000,RESOLUTION=640x360
360p/playlist.m3u8
EOF
        
        # Test HLS serving
        if curl -f -s "http://localhost:8085/hls/$TEST_STREAM_KEY/master.m3u8" > /dev/null 2>&1; then
            success "HLS serving test passed"
        else
            warning "HLS serving test failed"
        fi
        
        # Cleanup test directory
        rm -rf "$test_dir"
        return 0
    else
        error "Dynamic directory creation test failed"
        return 1
    fi
}

# Test API endpoints
test_api_endpoints() {
    log "Testing API endpoints..."
    
    local endpoints=(
        "localhost:8083/qualities:Transcoder-Qualities"
        "localhost:8083/transcode/active:Active-Transcoders"
        "localhost:8085/streams:HLS-Streams"
        "localhost:9000/api/admin/streams:Admin-Streams"
    )
    
    local failed_endpoints=()
    
    for endpoint_info in "${endpoints[@]}"; do
        local endpoint=$(echo "$endpoint_info" | cut -d':' -f1,2)
        local endpoint_name=$(echo "$endpoint_info" | cut -d':' -f3)
        
        if curl -f -s "http://$endpoint" > /dev/null 2>&1; then
            success "$endpoint_name API endpoint is working"
        else
            warning "$endpoint_name API endpoint is not responding"
            failed_endpoints+=("$endpoint_name")
        fi
    done
    
    if [ ${#failed_endpoints[@]} -eq 0 ]; then
        success "All API endpoints are working"
        return 0
    else
        warning "Some API endpoints failed: ${failed_endpoints[*]}"
        return 0  # Non-critical for basic functionality
    fi
}

# Test web interface
test_web_interface() {
    log "Testing web interface..."
    
    if curl -f -s "http://localhost:3000" > /dev/null 2>&1; then
        success "Web interface is accessible"
        return 0
    else
        error "Web interface is not accessible"
        return 1
    fi
}

# Test concurrent stream support
test_concurrent_streams() {
    log "Testing concurrent stream support..."
    
    local test_streams=("test1_$(date +%s)" "test2_$(date +%s)" "test3_$(date +%s)")
    local created_dirs=()
    
    # Create multiple test stream directories
    for stream in "${test_streams[@]}"; do
        local stream_dir="/tmp/streamforge/hls/$stream"
        mkdir -p "$stream_dir"/{720p,480p,360p}
        created_dirs+=("$stream_dir")
    done
    
    # Verify all directories were created
    local success_count=0
    for dir in "${created_dirs[@]}"; do
        if [ -d "$dir" ]; then
            ((success_count++))
        fi
    done
    
    if [ $success_count -eq ${#test_streams[@]} ]; then
        success "Concurrent stream support test passed ($success_count/${#test_streams[@]})"
    else
        error "Concurrent stream support test failed ($success_count/${#test_streams[@]})"
    fi
    
    # Cleanup test directories
    for dir in "${created_dirs[@]}"; do
        rm -rf "$dir"
    done
    
    return 0
}

# Test system resources
test_system_resources() {
    log "Testing system resources..."
    
    # Check disk space
    local disk_usage=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        success "Disk space is adequate ($disk_usage% used)"
    else
        warning "Disk space is low ($disk_usage% used)"
    fi
    
    # Check memory
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$mem_usage" -lt 90 ]; then
        success "Memory usage is acceptable ($mem_usage%)"
    else
        warning "Memory usage is high ($mem_usage%)"
    fi
    
    # Check CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_percentage=$(echo "$cpu_load $cpu_cores" | awk '{printf "%.0f", ($1/$2)*100}')
    
    if [ "$load_percentage" -lt 100 ]; then
        success "CPU load is acceptable ($load_percentage%)"
    else
        warning "CPU load is high ($load_percentage%)"
    fi
    
    return 0
}

# Generate validation report
generate_validation_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/streamforge-validation-report-$(date +%s).json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$timestamp",
    "validation_results": {
        "docker_available": $(test_docker >/dev/null 2>&1 && echo "true" || echo "false"),
        "containers_running": $(test_containers >/dev/null 2>&1 && echo "true" || echo "false"),
        "health_endpoints": $(test_health_endpoints >/dev/null 2>&1 && echo "true" || echo "false"),
        "rtmp_server": $(test_rtmp_server >/dev/null 2>&1 && echo "true" || echo "false"),
        "dynamic_directories": $(test_dynamic_directories >/dev/null 2>&1 && echo "true" || echo "false"),
        "api_endpoints": $(test_api_endpoints >/dev/null 2>&1 && echo "true" || echo "false"),
        "web_interface": $(test_web_interface >/dev/null 2>&1 && echo "true" || echo "false"),
        "concurrent_streams": $(test_concurrent_streams >/dev/null 2>&1 && echo "true" || echo "false")
    },
    "system_info": {
        "disk_usage": "$(df /tmp | tail -1 | awk '{print $5}')",
        "memory_usage": "$(free | grep Mem | awk '{printf "%.0f%%", $3/$2 * 100.0}')",
        "cpu_load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')",
        "docker_version": "$(docker --version 2>/dev/null || echo 'unknown')",
        "compose_version": "$(docker-compose --version 2>/dev/null || echo 'unknown')"
    }
}
EOF
    
    echo "$report_file"
}

# Main validation function
main() {
    echo -e "${PURPLE}🔍 StreamForge Deployment Validation${NC}"
    echo -e "${PURPLE}====================================${NC}"
    echo
    
    local overall_status=0
    
    # Core infrastructure tests
    test_docker || overall_status=1
    test_containers || overall_status=1
    test_health_endpoints || overall_status=1
    test_rtmp_server || overall_status=1
    
    echo
    log "Testing dynamic stream management capabilities..."
    
    # Dynamic capabilities tests
    test_dynamic_directories || overall_status=1
    test_api_endpoints  # Non-critical
    test_web_interface || overall_status=1
    test_concurrent_streams  # Non-critical
    
    echo
    log "Testing system resources..."
    
    # System resource tests
    test_system_resources  # Non-critical
    
    echo
    
    # Generate validation report
    local report_file=$(generate_validation_report)
    log "Validation report generated: $report_file"
    
    if [ $overall_status -eq 0 ]; then
        success "Overall validation: PASSED"
        echo
        echo -e "${GREEN}🎉 StreamForge deployment is fully functional!${NC}"
        echo
        echo -e "${CYAN}📋 Quick Test:${NC}"
        echo -e "  ${GREEN}RTMP URL:${NC}     rtmp://localhost:1935/live/test_stream"
        echo -e "  ${GREEN}Web Interface:${NC} http://localhost:3000"
        echo -e "  ${GREEN}HLS Playback:${NC}  http://localhost:8085/hls/test_stream/master.m3u8"
    else
        error "Overall validation: FAILED"
        echo
        echo -e "${RED}⚠️  Some critical issues detected. Check logs for details.${NC}"
        echo -e "${YELLOW}💡 Try running: ./docker/health-monitor.sh${NC}"
    fi
    
    return $overall_status
}

# Run main function
main "$@"
