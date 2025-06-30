#!/bin/bash

# StreamForge Docker Deployment Script
# One-command deployment for the entire streaming platform

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
PROJECT_NAME="streamforge"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    sudo mkdir -p /tmp/streamforge/{hls,recordings}
    sudo chmod 755 /tmp/streamforge/{hls,recordings}
    mkdir -p ./logs
    
    success "Directories created successfully"
}

# Create environment file
create_env_file() {
    log "Creating environment configuration..."
    
    cat > $ENV_FILE << EOF
# StreamForge Environment Configuration
COMPOSE_PROJECT_NAME=$PROJECT_NAME

# Service Ports
RTMP_PORT=1935
HTTP_PORT=8080
TRANSCODER_PORT=8083
HLS_SERVER_PORT=8085
ADMIN_API_PORT=9000
STREAM_MANAGER_PORT=8081
WEB_PORT=3000

# Directories
HLS_DIR=/tmp/streamforge/hls
RECORDINGS_DIR=/tmp/streamforge/recordings
LOGS_DIR=./logs

# Service URLs (internal)
RTMP_URL=rtmp://nginx-rtmp:1935/live
TRANSCODER_URL=http://transcoder:8083
NGINX_URL=http://nginx-rtmp:8080

# Performance Settings
NGINX_WORKER_PROCESSES=auto
GIN_MODE=release

# Security
STREAMFORGE_SECRET=streamforge-docker-secret-$(date +%s)
EOF
    
    success "Environment file created"
}

# Build and start services
start_services() {
    log "Building and starting StreamForge services..."
    
    # Stop any existing containers
    docker-compose -f $COMPOSE_FILE down --remove-orphans 2>/dev/null || true
    
    # Build images
    log "Building Docker images..."
    docker-compose -f $COMPOSE_FILE build --no-cache
    
    # Start services with dependency order
    log "Starting services..."
    docker-compose -f $COMPOSE_FILE up -d
    
    success "Services started successfully"
}

# Wait for services to be healthy
wait_for_services() {
    log "Waiting for services to become healthy..."
    
    local services=("transcoder" "hls-server" "admin-api" "nginx-rtmp" "web-interface")
    local max_wait=120
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        local all_healthy=true
        
        for service in "${services[@]}"; do
            if ! docker-compose -f $COMPOSE_FILE ps $service | grep -q "healthy\|Up"; then
                all_healthy=false
                break
            fi
        done
        
        if [ "$all_healthy" = true ]; then
            success "All services are healthy"
            return 0
        fi
        
        echo -n "."
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    warning "Some services may not be fully ready yet. Check logs if needed."
}

# Display service information
show_service_info() {
    log "StreamForge Platform is ready!"
    echo
    echo -e "${CYAN}🎬 StreamForge Services:${NC}"
    echo -e "  ${GREEN}Web Interface:${NC}     http://localhost:3000"
    echo -e "  ${GREEN}RTMP Ingestion:${NC}    rtmp://localhost:1935/live/{stream_key}"
    echo -e "  ${GREEN}HLS Playback:${NC}      http://localhost:8085/hls/{stream_key}/master.m3u8"
    echo -e "  ${GREEN}Admin API:${NC}         http://localhost:9000/health"
    echo -e "  ${GREEN}Transcoder API:${NC}    http://localhost:8083/health"
    echo
    echo -e "${CYAN}📊 Monitoring:${NC}"
    echo -e "  ${GREEN}Service Status:${NC}    docker-compose -f $COMPOSE_FILE ps"
    echo -e "  ${GREEN}Service Logs:${NC}      docker-compose -f $COMPOSE_FILE logs -f [service_name]"
    echo -e "  ${GREEN}NGINX Stats:${NC}       http://localhost:8080/stat"
    echo
    echo -e "${CYAN}🔧 Management:${NC}"
    echo -e "  ${GREEN}Stop Platform:${NC}     docker-compose -f $COMPOSE_FILE down"
    echo -e "  ${GREEN}Restart Service:${NC}   docker-compose -f $COMPOSE_FILE restart [service_name]"
    echo -e "  ${GREEN}View Logs:${NC}         docker-compose -f $COMPOSE_FILE logs -f"
    echo
    echo -e "${YELLOW}📝 Example RTMP Stream:${NC}"
    echo -e "  ${GREEN}OBS Studio URL:${NC}    rtmp://localhost:1935/live"
    echo -e "  ${GREEN}Stream Key:${NC}        test_stream"
    echo -e "  ${GREEN}Playback URL:${NC}      http://localhost:3000 (then select 'test_stream')"
    echo
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 StreamForge Docker Deployment${NC}"
    echo -e "${PURPLE}=================================${NC}"
    echo
    
    check_prerequisites
    create_directories
    create_env_file
    start_services
    wait_for_services
    show_service_info
    
    echo -e "${GREEN}🎉 StreamForge deployment completed successfully!${NC}"
    echo

    # Run deployment validation
    log "Running deployment validation..."
    if [ -f "./docker/validate-deployment.sh" ]; then
        chmod +x ./docker/validate-deployment.sh
        if ./docker/validate-deployment.sh; then
            success "Deployment validation passed"
        else
            warning "Deployment validation found some issues"
        fi
    else
        warning "Validation script not found, skipping validation"
    fi
}

# Run main function
main "$@"
