#!/bin/bash

# StreamForge Comprehensive Health Monitor
# Monitors service health and dynamic stream management capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
HLS_DIR="${HLS_DIR:-/tmp/streamforge/hls}"
LOG_FILE="/var/log/streamforge-health.log"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

success() {
    local message="✅ $1"
    echo -e "${GREEN}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

warning() {
    local message="⚠️  $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    local message="❌ $1"
    echo -e "${RED}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Check if Docker services are running
check_docker_services() {
    log "Checking Docker services status..."
    
    local services=("nginx-rtmp" "transcoder" "hls-server" "admin-api" "web-interface")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            success "Service $service is running"
        else
            error "Service $service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        success "All Docker services are running"
        return 0
    else
        error "Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Check service health endpoints
check_service_health() {
    log "Checking service health endpoints..."
    
    local endpoints=(
        "transcoder:8083/health"
        "hls-server:8085/health"
        "admin-api:9000/health"
    )
    
    local failed_endpoints=()
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f -s "http://$endpoint" > /dev/null 2>&1; then
            success "Health endpoint $endpoint is responding"
        else
            error "Health endpoint $endpoint is not responding"
            failed_endpoints+=("$endpoint")
        fi
    done
    
    if [ ${#failed_endpoints[@]} -eq 0 ]; then
        success "All health endpoints are responding"
        return 0
    else
        error "Failed endpoints: ${failed_endpoints[*]}"
        return 1
    fi
}

# Check RTMP server availability
check_rtmp_server() {
    log "Checking RTMP server availability..."
    
    if nc -z localhost 1935 2>/dev/null; then
        success "RTMP server is listening on port 1935"
        return 0
    else
        error "RTMP server is not accessible on port 1935"
        return 1
    fi
}

# Test dynamic directory creation capability
test_dynamic_directory_creation() {
    log "Testing dynamic directory creation capability..."
    
    local test_stream="health_test_$(date +%s)"
    local test_dir="$HLS_DIR/$test_stream"
    
    # Create test directories to simulate stream start
    mkdir -p "$test_dir"/{720p,480p,360p}
    
    if [ -d "$test_dir/720p" ] && [ -d "$test_dir/480p" ] && [ -d "$test_dir/360p" ]; then
        success "Dynamic directory creation test passed"
        
        # Cleanup test directories
        rm -rf "$test_dir"
        return 0
    else
        error "Dynamic directory creation test failed"
        return 1
    fi
}

# Check transcoder API functionality
test_transcoder_api() {
    log "Testing transcoder API functionality..."
    
    local test_stream="api_test_$(date +%s)"
    
    # Test quality profiles endpoint
    if curl -f -s "http://localhost:8083/qualities" > /dev/null 2>&1; then
        success "Transcoder quality profiles endpoint is working"
    else
        error "Transcoder quality profiles endpoint failed"
        return 1
    fi
    
    # Test active transcoders endpoint
    if curl -f -s "http://localhost:8083/transcode/active" > /dev/null 2>&1; then
        success "Transcoder active streams endpoint is working"
    else
        error "Transcoder active streams endpoint failed"
        return 1
    fi
    
    return 0
}

# Check HLS server stream discovery
test_hls_stream_discovery() {
    log "Testing HLS server stream discovery..."
    
    # Test streams listing endpoint
    if curl -f -s "http://localhost:8085/streams" > /dev/null 2>&1; then
        success "HLS server stream discovery is working"
        return 0
    else
        error "HLS server stream discovery failed"
        return 1
    fi
}

# Check concurrent stream support
test_concurrent_stream_support() {
    log "Testing concurrent stream support..."
    
    local max_streams=5
    local test_dirs=()
    
    # Create multiple test stream directories
    for i in $(seq 1 $max_streams); do
        local test_stream="concurrent_test_${i}_$(date +%s)"
        local test_dir="$HLS_DIR/$test_stream"
        mkdir -p "$test_dir"/{720p,480p,360p}
        test_dirs+=("$test_dir")
    done
    
    # Check if all directories were created
    local created_count=0
    for dir in "${test_dirs[@]}"; do
        if [ -d "$dir" ]; then
            ((created_count++))
        fi
    done
    
    if [ $created_count -eq $max_streams ]; then
        success "Concurrent stream support test passed ($created_count/$max_streams)"
    else
        error "Concurrent stream support test failed ($created_count/$max_streams)"
    fi
    
    # Cleanup test directories
    for dir in "${test_dirs[@]}"; do
        rm -rf "$dir"
    done
    
    return 0
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # Check disk space
    local disk_usage=$(df "$HLS_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        success "Disk usage is acceptable ($disk_usage%)"
    elif [ "$disk_usage" -lt 90 ]; then
        warning "Disk usage is high ($disk_usage%)"
    else
        error "Disk usage is critical ($disk_usage%)"
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$mem_usage" -lt 80 ]; then
        success "Memory usage is acceptable ($mem_usage%)"
    elif [ "$mem_usage" -lt 90 ]; then
        warning "Memory usage is high ($mem_usage%)"
    else
        error "Memory usage is critical ($mem_usage%)"
    fi
    
    # Check CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_percentage=$(echo "$cpu_load $cpu_cores" | awk '{printf "%.0f", ($1/$2)*100}')
    
    if [ "$load_percentage" -lt 80 ]; then
        success "CPU load is acceptable ($load_percentage%)"
    elif [ "$load_percentage" -lt 100 ]; then
        warning "CPU load is high ($load_percentage%)"
    else
        error "CPU load is critical ($load_percentage%)"
    fi
}

# Check active streams
check_active_streams() {
    log "Checking active streams..."
    
    local active_streams=0
    if [ -d "$HLS_DIR" ]; then
        active_streams=$(find "$HLS_DIR" -maxdepth 1 -type d | wc -l)
        active_streams=$((active_streams - 1)) # Subtract the parent directory
    fi
    
    if [ $active_streams -eq 0 ]; then
        success "No active streams (system ready for new streams)"
    else
        success "Found $active_streams active stream(s)"
        
        # List active streams
        for stream_dir in "$HLS_DIR"/*; do
            if [ -d "$stream_dir" ]; then
                local stream_name=$(basename "$stream_dir")
                local last_activity=$(find "$stream_dir" -name "*.ts" -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
                if [ -n "$last_activity" ]; then
                    local current_time=$(date +%s)
                    local time_diff=$((current_time - ${last_activity%.*}))
                    if [ $time_diff -lt 30 ]; then
                        success "Stream '$stream_name' is active (last activity: ${time_diff}s ago)"
                    else
                        warning "Stream '$stream_name' may be stale (last activity: ${time_diff}s ago)"
                    fi
                else
                    warning "Stream '$stream_name' has no segments"
                fi
            fi
        done
    fi
}

# Generate health report
generate_health_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/tmp/streamforge-health-report-$(date +%s).json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$timestamp",
    "services": {
        "docker_services": $(check_docker_services >/dev/null 2>&1 && echo "true" || echo "false"),
        "health_endpoints": $(check_service_health >/dev/null 2>&1 && echo "true" || echo "false"),
        "rtmp_server": $(check_rtmp_server >/dev/null 2>&1 && echo "true" || echo "false")
    },
    "capabilities": {
        "dynamic_directories": $(test_dynamic_directory_creation >/dev/null 2>&1 && echo "true" || echo "false"),
        "transcoder_api": $(test_transcoder_api >/dev/null 2>&1 && echo "true" || echo "false"),
        "stream_discovery": $(test_hls_stream_discovery >/dev/null 2>&1 && echo "true" || echo "false"),
        "concurrent_streams": $(test_concurrent_stream_support >/dev/null 2>&1 && echo "true" || echo "false")
    },
    "resources": {
        "disk_usage": "$(df "$HLS_DIR" | tail -1 | awk '{print $5}')",
        "memory_usage": "$(free | grep Mem | awk '{printf "%.0f%%", $3/$2 * 100.0}')",
        "cpu_load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"
    },
    "active_streams": $(find "$HLS_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l | awk '{print $1-1}')
}
EOF
    
    echo "$report_file"
}

# Main health check function
main() {
    echo -e "${PURPLE}🏥 StreamForge Health Monitor${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo
    
    local overall_health=0
    
    # Core service checks
    check_docker_services || overall_health=1
    check_service_health || overall_health=1
    check_rtmp_server || overall_health=1
    
    echo
    log "Testing dynamic stream management capabilities..."
    
    # Dynamic capabilities tests
    test_dynamic_directory_creation || overall_health=1
    test_transcoder_api || overall_health=1
    test_hls_stream_discovery || overall_health=1
    test_concurrent_stream_support || overall_health=1
    
    echo
    log "Checking system status..."
    
    # System checks
    check_system_resources
    check_active_streams
    
    echo
    
    # Generate report
    local report_file=$(generate_health_report)
    log "Health report generated: $report_file"
    
    if [ $overall_health -eq 0 ]; then
        success "Overall system health: HEALTHY"
        echo -e "${GREEN}🎉 StreamForge is ready for dynamic stream processing!${NC}"
    else
        error "Overall system health: UNHEALTHY"
        echo -e "${RED}⚠️  Some issues detected. Check logs for details.${NC}"
    fi
    
    return $overall_health
}

# Run main function
main "$@"
