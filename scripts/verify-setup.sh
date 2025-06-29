#!/bin/bash

# StreamForge Setup Verification Script
# Tests all services and components

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}🔍 StreamForge Setup Verification${NC}"
echo "=================================="

# Test 1: Service Health Checks
echo -e "\n${BLUE}1. Testing Service Health...${NC}"

check_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    if response=$(curl -s "$url" 2>/dev/null); then
        if echo "$response" | grep -q "$expected"; then
            success "$name is healthy"
            return 0
        else
            error "$name returned unexpected response: $response"
            return 1
        fi
    else
        error "$name is not responding on $url"
        return 1
    fi
}

services_ok=true

check_service "Transcoder" "http://localhost:8083/health" "healthy" || services_ok=false
check_service "HLS Server" "http://localhost:8085/health" "healthy" || services_ok=false  
check_service "Admin API" "http://localhost:9000/health" "healthy" || services_ok=false
check_service "NGINX" "http://localhost:8080/health" "healthy" || services_ok=false

# Test 2: Directory Structure
echo -e "\n${BLUE}2. Checking Directory Structure...${NC}"

check_directory() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        success "$description exists: $dir"
        return 0
    else
        error "$description missing: $dir"
        return 1
    fi
}

dirs_ok=true
check_directory "/tmp/hls_shared" "HLS output directory" || dirs_ok=false
check_directory "/root/STREAMFORGE/logs" "Logs directory" || dirs_ok=false

# Test 3: Process Check
echo -e "\n${BLUE}3. Checking Running Processes...${NC}"

check_process() {
    local name=$1
    local pattern=$2
    
    if pgrep -f "$pattern" > /dev/null; then
        local pid=$(pgrep -f "$pattern" | head -1)
        success "$name is running (PID: $pid)"
        return 0
    else
        error "$name is not running"
        return 1
    fi
}

processes_ok=true
check_process "Transcoder service" "transcoder" || processes_ok=false
check_process "HLS Server" "hls-server" || processes_ok=false
check_process "Admin API" "admin-api" || processes_ok=false

# Test 4: Port Availability
echo -e "\n${BLUE}4. Checking Port Usage...${NC}"

check_port() {
    local port=$1
    local service=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        success "Port $port is in use by $service"
        return 0
    else
        error "Port $port is not in use (expected for $service)"
        return 1
    fi
}

ports_ok=true
check_port "1935" "RTMP (NGINX)" || ports_ok=false
check_port "8080" "HTTP (NGINX)" || ports_ok=false
check_port "8083" "Transcoder API" || ports_ok=false
check_port "8085" "HLS Server" || ports_ok=false
check_port "9000" "Admin API" || ports_ok=false

# Test 5: API Endpoints
echo -e "\n${BLUE}5. Testing API Endpoints...${NC}"

test_api() {
    local name=$1
    local url=$2
    local expected_code=$3
    
    if response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
        if [ "$response_code" = "$expected_code" ]; then
            success "$name API responds correctly (HTTP $response_code)"
            return 0
        else
            error "$name API returned HTTP $response_code (expected $expected_code)"
            return 1
        fi
    else
        error "$name API is not responding"
        return 1
    fi
}

apis_ok=true
test_api "Transcoder qualities" "http://localhost:8083/qualities" "200" || apis_ok=false
test_api "HLS streams list" "http://localhost:8085/streams" "200" || apis_ok=false
test_api "Admin disk usage" "http://localhost:9000/api/admin/disk-usage" "200" || apis_ok=false

# Test 6: Docker Status
echo -e "\n${BLUE}6. Checking Docker Services...${NC}"

if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "nginx-rtmp"; then
    success "NGINX-RTMP container is running"
    docker_ok=true
else
    error "NGINX-RTMP container is not running"
    info "Try: docker-compose up -d nginx-rtmp"
    docker_ok=false
fi

# Summary
echo -e "\n${BLUE}📋 Verification Summary${NC}"
echo "======================="

overall_ok=true

if $services_ok; then
    success "All services are healthy"
else
    error "Some services are unhealthy"
    overall_ok=false
fi

if $dirs_ok; then
    success "Directory structure is correct"
else
    error "Directory structure has issues"
    overall_ok=false
fi

if $processes_ok; then
    success "All processes are running"
else
    error "Some processes are not running"
    overall_ok=false
fi

if $ports_ok; then
    success "All required ports are in use"
else
    error "Some ports are not in use"
    overall_ok=false
fi

if $apis_ok; then
    success "All APIs are responding"
else
    error "Some APIs are not responding"
    overall_ok=false
fi

if $docker_ok; then
    success "Docker services are running"
else
    error "Docker services need attention"
    overall_ok=false
fi

echo
if $overall_ok; then
    success "🎉 StreamForge is ready for streaming!"
    echo
    info "To start streaming:"
    echo "  • OBS Server: rtmp://localhost:1935/live"
    echo "  • Stream Key: mystream (or any name)"
    echo "  • Watch URL: http://localhost:8085/hls/mystream/master.m3u8"
else
    error "❌ Setup has issues. Please fix them before streaming."
    echo
    info "Common fixes:"
    echo "  • Restart services: ./scripts/start-go-services.sh"
    echo "  • Start NGINX: docker-compose up -d nginx-rtmp"
    echo "  • Check logs: tail -f logs/*.log"
fi