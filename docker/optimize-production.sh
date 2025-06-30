#!/bin/bash

# StreamForge Production Optimization Script
# Configures the system for optimal production performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root for system optimizations"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Optimize kernel parameters for streaming
optimize_kernel() {
    log "Optimizing kernel parameters for streaming..."
    
    # Create sysctl configuration for streaming
    cat > /etc/sysctl.d/99-streamforge.conf << EOF
# StreamForge Kernel Optimizations

# Network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1

# File system optimizations
fs.file-max = 2097152
fs.nr_open = 1048576

# Memory optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Process limits
kernel.pid_max = 4194304
EOF

    # Apply the settings
    sysctl -p /etc/sysctl.d/99-streamforge.conf
    success "Kernel parameters optimized"
}

# Optimize system limits
optimize_limits() {
    log "Optimizing system limits..."
    
    # Create limits configuration
    cat > /etc/security/limits.d/99-streamforge.conf << EOF
# StreamForge System Limits

* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 1048576
root hard nproc 1048576
EOF

    success "System limits optimized"
}

# Configure Docker for production
optimize_docker() {
    log "Optimizing Docker configuration..."
    
    # Create Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "userland-proxy": false,
    "experimental": false,
    "metrics-addr": "127.0.0.1:9323",
    "default-ulimits": {
        "nofile": {
            "Hard": 1048576,
            "Name": "nofile",
            "Soft": 1048576
        },
        "nproc": {
            "Hard": 1048576,
            "Name": "nproc",
            "Soft": 1048576
        }
    }
}
EOF

    # Restart Docker to apply changes
    systemctl restart docker
    success "Docker configuration optimized"
}

# Create optimized directory structure
create_directories() {
    log "Creating optimized directory structure..."
    
    # Create directories with optimal permissions
    mkdir -p /opt/streamforge/{data,logs,config,backups}
    mkdir -p /tmp/streamforge/{hls,recordings,temp}
    
    # Set optimal permissions
    chmod 755 /opt/streamforge
    chmod 755 /tmp/streamforge
    chown -R 1001:1001 /opt/streamforge
    chown -R 1001:1001 /tmp/streamforge
    
    success "Directory structure created"
}

# Configure log rotation
configure_logging() {
    log "Configuring log rotation..."
    
    cat > /etc/logrotate.d/streamforge << EOF
/opt/streamforge/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 1001 1001
    postrotate
        docker-compose -f /opt/streamforge/docker-compose.yml restart > /dev/null 2>&1 || true
    endscript
}

/tmp/streamforge/logs/*.log {
    hourly
    missingok
    rotate 24
    compress
    delaycompress
    notifempty
    create 644 1001 1001
}
EOF

    success "Log rotation configured"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up basic monitoring..."
    
    # Create monitoring script
    cat > /usr/local/bin/streamforge-monitor << 'EOF'
#!/bin/bash
# StreamForge monitoring script

COMPOSE_FILE="/opt/streamforge/docker-compose.yml"
LOG_FILE="/var/log/streamforge-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if services are running
if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
    log "WARNING: Some StreamForge services are not running"
    # Optionally restart services
    # docker-compose -f "$COMPOSE_FILE" up -d
fi

# Check disk space
DISK_USAGE=$(df /tmp/streamforge | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt 80 ]; then
    log "WARNING: Memory usage is at ${MEM_USAGE}%"
fi
EOF

    chmod +x /usr/local/bin/streamforge-monitor
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/streamforge-monitor") | crontab -
    
    success "Monitoring configured"
}

# Create production environment file
create_production_env() {
    log "Creating production environment configuration..."
    
    cat > /opt/streamforge/.env << EOF
# StreamForge Production Configuration
COMPOSE_PROJECT_NAME=streamforge-prod

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
LOGS_DIR=/opt/streamforge/logs

# Service URLs
RTMP_URL=rtmp://nginx-rtmp:1935/live
TRANSCODER_URL=http://transcoder:8083
NGINX_URL=http://nginx-rtmp:8080

# Performance Settings
NGINX_WORKER_PROCESSES=auto
GIN_MODE=release

# Security
STREAMFORGE_SECRET=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)

# Production Optimizations
ENABLE_GZIP=true
ENABLE_CACHING=true
ENABLE_RATE_LIMITING=true
RATE_LIMIT_RPM=1000

# Monitoring
LOG_LEVEL=info
ENABLE_HEALTH_CHECKS=true
HEALTH_CHECK_INTERVAL=30
EOF

    success "Production environment configured"
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 StreamForge Production Optimization${NC}"
    echo -e "${PURPLE}=====================================${NC}"
    echo
    
    check_root
    optimize_kernel
    optimize_limits
    optimize_docker
    create_directories
    configure_logging
    setup_monitoring
    create_production_env
    
    echo
    echo -e "${GREEN}🎉 Production optimization completed!${NC}"
    echo
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "1. Copy your StreamForge files to /opt/streamforge/"
    echo -e "2. Run: cd /opt/streamforge && ./docker/start-streamforge.sh"
    echo -e "3. Monitor logs: tail -f /var/log/streamforge-monitor.log"
    echo
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo -e "- Reboot the system to ensure all optimizations take effect"
    echo -e "- Review and customize /opt/streamforge/.env for your needs"
    echo -e "- Set up proper firewall rules for the exposed ports"
}

# Run main function
main "$@"
