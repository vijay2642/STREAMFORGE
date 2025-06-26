# StreamForge Health Check & Startup Scripts

This directory contains three complementary scripts for managing the StreamForge live streaming platform's health and startup processes.

## 📁 Scripts Overview

### 1. `health-check.sh` - Read-Only Health Validator
**Purpose**: Comprehensive system status validation without making changes

```bash
./health-check.sh
```

**Features**:
- ✅ **Non-destructive**: Only reads system state, makes no changes
- 🔍 **Comprehensive scanning**: Checks all services, ports, processes, and endpoints
- 📊 **Detailed reporting**: Shows health percentage and specific issue details
- 🎯 **Smart exit codes**: Returns 0 for healthy (≥75%), 1 for unhealthy systems
- 🌐 **Endpoint validation**: Tests actual HTTP responses and accessibility

**Use Cases**:
- Development status checks
- CI/CD pipeline validation
- Troubleshooting and diagnostics
- Regular monitoring

### 2. `streamforge-quick-start.sh` - Intelligent Startup
**Purpose**: Smart startup with auto-detection and repair

```bash
./streamforge-quick-start.sh
```

**Features**:
- 🚀 **Auto-startup**: Starts missing services automatically
- 🔄 **Idempotent**: Safe to run multiple times
- 📦 **Mixed architecture**: Handles both Docker and Python services
- ⚡ **Fast execution**: Optimized for current system architecture
- 🛠️ **Auto-repair**: Fixes common issues automatically

**Use Cases**:
- Daily development startup
- Post-reboot system restoration
- Quick issue resolution
- Development environment setup

### 3. `streamforge-health-startup.sh` - Full Platform Manager
**Purpose**: Enterprise-grade health check and startup system

```bash
./streamforge-health-startup.sh
```

**Features**:
- 🏢 **Production-ready**: Full dependency management and retry logic
- 📋 **Comprehensive**: Supports all service types and configurations
- 🔄 **Retry logic**: Multiple attempts with exponential backoff
- 📝 **Detailed logging**: Complete audit trail in `/tmp/streamforge-startup.log`
- 🎛️ **Configurable**: Timeout and retry parameters
- 🔗 **Dependency aware**: Respects service startup order

**Use Cases**:
- Production deployments
- CI/CD automation
- Complete platform bootstrapping
- Enterprise monitoring integration

## 🔧 Current System Architecture

### Docker Services (Port-Based)
- **PostgreSQL Database**: Port 5432
- **Redis Cache**: Port 6379
- **NGINX RTMP Server**: Ports 1935 (RTMP), 8090 (HTTP)
- **Stream Transcoder**: Port 8082
- **Stream Processing**: Port 8081
- **User Management**: Port 8083
- **Web Player**: Port 3000 (Docker) or Python HTTP server

### Python Standalone Services
- **CORS/HLS Server**: Port 8085 (`cors_server.py`)
- **Live Transcoder**: FFmpeg processes (`live_transcoder.py`)

### Critical Files & Directories
- **HLS Playlists**: `/tmp/hls_shared/stream1/playlist.m3u8`, `/tmp/hls_shared/stream3/playlist.m3u8`
- **HLS Segments**: `/tmp/hls_shared/stream*/segment_*.ts`
- **Docker Compose**: `docker-compose.yml`

## 📊 Health Check Categories

### Infrastructure (4 services)
- Docker Engine availability
- Database connectivity (PostgreSQL)
- Cache availability (Redis)
- RTMP ingestion server (NGINX)

### Application Services (4 services)
- Stream transcoder API
- Stream processing engine
- User management system
- Web player interface

### Python Services (2 services)
- CORS/HLS content server
- Live transcoding processes

### Streaming Content (2 streams)
- Stream1 HLS playlist and segments
- Stream3 HLS playlist and segments

### Endpoint Accessibility (4 endpoints)
- Web player test page
- HLS stream endpoints
- NGINX statistics page

## 🚀 Quick Start Guide

### For Development
```bash
# Check current status
./health-check.sh

# If issues found, auto-fix them
./streamforge-quick-start.sh

# Verify everything is working
./health-check.sh
```

### For Production
```bash
# Full enterprise startup
./streamforge-health-startup.sh

# Check logs if issues
tail -f /tmp/streamforge-startup.log
```

### For Troubleshooting
```bash
# Get detailed status
./health-check.sh

# Check Docker containers
docker ps
docker-compose logs

# Check Python processes
ps aux | grep -E "(cors_server|live_transcoder|ffmpeg)"

# Check HLS content
ls -la /tmp/hls_shared/stream*/
curl -I http://localhost:8085/stream1/playlist.m3u8
```

## 🎯 Health Status Indicators

### ✅ Healthy (Green)
- Service is running and responsive
- All health checks pass
- Endpoints accessible

### ⚠️ Warning (Yellow)
- Service partially functional
- Minor issues detected
- May need attention

### ❌ Failed (Red)
- Service not running
- Critical functionality broken
- Immediate attention required

## 📈 Health Percentage Thresholds

- **90-100%**: 🎉 Excellent - Production ready
- **75-89%**: ⚠️ Good - Minor issues, mostly functional
- **50-74%**: 🚧 Partial - Significant issues, manual intervention needed
- **0-49%**: 🚨 Critical - Multiple failures, platform unusable

## 🌐 Key Endpoints

### Live Streaming
- **Web Player**: http://localhost:3000/test-player.html
- **RTMP Ingest**: rtmp://localhost:1935/live/stream1
- **HLS Stream 1**: http://localhost:8085/stream1/playlist.m3u8
- **HLS Stream 3**: http://localhost:8085/stream3/playlist.m3u8

### Management & Monitoring
- **Transcoder API**: http://localhost:8082
- **Stream Processing**: http://localhost:8081
- **User Management**: http://localhost:8083
- **NGINX Stats**: http://localhost:8090/stat
- **CORS Server**: http://localhost:8085

## 📝 Log Files

- **Quick Start**: `/tmp/streamforge-quickstart.log`
- **Full Startup**: `/tmp/streamforge-startup.log`
- **Docker Logs**: `docker-compose logs [service_name]`
- **CORS Server**: `cors_server.log`

## 🔄 Integration with User Input System

All scripts integrate with the existing `userinput.py` workflow:

```bash
# After running any script
python3 userinput.py
# Enter feedback or "stop" to exit
```

## 🛠️ Customization

### Environment Variables
```bash
# Override timeouts
export TIMEOUT_STARTUP=60
export TIMEOUT_HEALTH=15
export MAX_RETRIES=5

# Custom log location
export LOG_FILE="/var/log/streamforge.log"
```

### Script Modifications
- Edit service definitions in the script arrays
- Modify health check logic for custom services
- Add new service types to the startup functions

## 🚨 Common Issues & Solutions

### Empty HLS Playlists
```bash
# Restart live transcoder
pkill -f live_transcoder.py
python3 live_transcoder.py both &
```

### Docker Services Not Starting
```bash
# Check Docker daemon
sudo systemctl restart docker
docker-compose down && docker-compose up -d
```

### Port Conflicts
```bash
# Check what's using a port
sudo netstat -tlpn | grep :8085
sudo lsof -i :8085
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x *.sh

# Fix directory permissions
sudo chown -R $USER:$USER /tmp/hls_shared/
```

---

**Note**: These scripts are designed to work with the current StreamForge architecture mixing Docker containerized services with standalone Python processes. They provide comprehensive health monitoring and intelligent startup capabilities for both development and production environments. 