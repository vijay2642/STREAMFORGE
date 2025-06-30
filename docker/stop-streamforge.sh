#!/bin/bash

# StreamForge Docker Stop Script
# Gracefully stops all StreamForge services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"

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

# Stop services gracefully
stop_services() {
    log "Stopping StreamForge services..."
    
    if [ -f "$COMPOSE_FILE" ]; then
        docker-compose -f $COMPOSE_FILE down --remove-orphans
        success "Services stopped successfully"
    else
        error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
}

# Clean up resources (optional)
cleanup_resources() {
    local cleanup_volumes=false
    local cleanup_images=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --volumes)
                cleanup_volumes=true
                shift
                ;;
            --images)
                cleanup_images=true
                shift
                ;;
            --all)
                cleanup_volumes=true
                cleanup_images=true
                shift
                ;;
            *)
                warning "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    if [ "$cleanup_volumes" = true ]; then
        log "Cleaning up volumes..."
        docker volume prune -f
        success "Volumes cleaned up"
    fi
    
    if [ "$cleanup_images" = true ]; then
        log "Cleaning up images..."
        docker image prune -f
        success "Images cleaned up"
    fi
}

# Show status
show_status() {
    log "Checking remaining containers..."
    
    local running_containers=$(docker ps --filter "name=streamforge" --format "table {{.Names}}\t{{.Status}}")
    
    if [ -z "$running_containers" ] || [ "$running_containers" = "NAMES	STATUS" ]; then
        success "No StreamForge containers are running"
    else
        warning "Some containers are still running:"
        echo "$running_containers"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🛑 StreamForge Docker Stop${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo
    
    stop_services
    cleanup_resources "$@"
    show_status
    
    echo
    echo -e "${GREEN}🎉 StreamForge stopped successfully!${NC}"
    echo
    echo -e "${YELLOW}💡 To restart StreamForge:${NC}"
    echo -e "   ./docker/start-streamforge.sh"
    echo
    echo -e "${YELLOW}💡 To clean up everything:${NC}"
    echo -e "   ./docker/stop-streamforge.sh --all"
}

# Run main function
main "$@"
