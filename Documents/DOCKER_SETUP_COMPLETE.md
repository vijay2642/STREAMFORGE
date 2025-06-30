# StreamForge Complete Docker Setup Guide

## 🚀 One-Command Deployment with Dynamic Stream Management

This guide provides a comprehensive Docker setup for StreamForge that handles ALL dependencies and configuration automatically, with advanced dynamic stream management capabilities.

## ✨ Key Features

### 🎯 Complete Environment Setup
- ✅ Automatically installs and configures all required libraries, dependencies, and tools
- ✅ NGINX-RTMP server with FFmpeg integration
- ✅ Go-based transcoder, HLS server, admin API, and stream manager services
- ✅ Web interface with CORS configuration

### 📁 Automatic Directory Structure
- ✅ Creates all necessary directories (`/tmp/hls_shared`, logs, etc.) with proper permissions
- ✅ **Dynamic directory creation** for new streams:
  - `/tmp/hls_shared/{stream_key}/720p/`
  - `/tmp/hls_shared/{stream_key}/480p/`
  - `/tmp/hls_shared/{stream_key}/360p/`
  - Master playlist generation

### 🔄 Dynamic Stream Management
- ✅ **Automatic stream detection** when publishing to `rtmp://localhost:1935/live/{stream_key}`
- ✅ **No manual intervention** required for new streams
- ✅ **No service restarts** needed
- ✅ **Concurrent stream support** with independent processing
- ✅ **Real-time stream discovery** by HLS server and admin API

### 🎬 Automatic Transcoding
- ✅ NGINX exec directives trigger FFmpeg transcoding automatically
- ✅ Multi-quality adaptive bitrate streaming (720p, 480p, 360p)
- ✅ HLS segments (.ts) and playlists (.m3u8) generated automatically
- ✅ Optimized for buffer-free streaming

### 🧹 Stream Lifecycle Management
- ✅ **Proper cleanup** when streams end
- ✅ **Configurable retention policies** (24 hours default)
- ✅ **Automatic segment cleanup** based on age
- ✅ **Process termination** handling

### 🌐 Network & Storage
- ✅ All required ports exposed (1935 RTMP, 8080 HLS, 3000 web, 8083 transcoder API)
- ✅ Persistent storage with proper volume mounting
- ✅ HLS files and logs accessible from host system

## 🚀 Quick Start (One Command!)

```bash
# 1. Setup (one-time)
chmod +x setup-docker.sh
./setup-docker.sh

# 2. Deploy entire platform
./docker/start-streamforge.sh
```

**That's it!** The entire StreamForge platform is now running and ready for live streams.

## ⚡ Quick Reference Commands

```bash
# 🚀 START SERVICES
./docker/start-streamforge.sh

# 🛑 STOP SERVICES
./docker/stop-streamforge.sh

# 🔍 CHECK STATUS
docker-compose ps
./docker/health-monitor.sh

# 📊 VIEW LOGS
docker-compose logs -f

# 🧹 CLEANUP
./docker/stream-cleanup.sh

# 🔄 RESTART
docker-compose restart
```

## 📊 Service Architecture

| Service | Port | Container | Purpose |
|---------|------|-----------|---------|
| **NGINX-RTMP** | 1935, 8080 | `streamforge-nginx-rtmp` | RTMP ingestion & HTTP serving |
| **Transcoder** | 8083 | `streamforge-transcoder` | Multi-quality transcoding API |
| **HLS Server** | 8085 | `streamforge-hls-server` | Optimized HLS file serving |
| **Admin API** | 9000 | `streamforge-admin-api` | System monitoring & management |
| **Web Interface** | 3000 | `streamforge-web` | User-friendly streaming interface |
| **Stream Manager** | 8081 | `streamforge-stream-manager` | Advanced stream lifecycle |

## 🎯 Dynamic Stream Management in Action

### When you publish a stream to `rtmp://localhost:1935/live/my_stream`:

1. **Automatic Directory Creation** (via `on_publish.sh`):
   ```
   /tmp/hls_shared/my_stream/
   ├── master.m3u8              # Master playlist
   ├── 720p/
   │   ├── playlist.m3u8        # 720p playlist
   │   └── segment*.ts          # 720p segments
   ├── 480p/
   │   ├── playlist.m3u8        # 480p playlist
   │   └── segment*.ts          # 480p segments
   └── 360p/
       ├── playlist.m3u8        # 360p playlist
       └── segment*.ts          # 360p segments
   ```

2. **Automatic Transcoding** (via `transcode-enhanced.sh`):
   - FFmpeg starts automatically
   - Generates 3 quality levels simultaneously
   - Creates HLS segments every 2 seconds
   - Updates playlists in real-time

3. **Real-time Discovery**:
   - HLS server immediately serves the new stream
   - Admin API shows stream status
   - Web interface lists the stream automatically

4. **Stream Cleanup** (via `on_publish_done.sh`):
   - Stops transcoding processes
   - Applies retention policy
   - Marks stream as ended

## 🔍 Health Monitoring & Validation

### Comprehensive Health Checks
```bash
# Run full health monitoring
./docker/health-monitor.sh

# Validate deployment
./docker/validate-deployment.sh
```

**Tests performed:**
- ✅ Docker service status
- ✅ Health endpoint responses  
- ✅ RTMP server availability
- ✅ Dynamic directory creation capability
- ✅ Transcoder API functionality
- ✅ Stream discovery capability
- ✅ Concurrent stream support
- ✅ System resource usage

## 🎬 Usage Examples

### Stream with OBS Studio
1. **RTMP Settings**:
   - Server: `rtmp://localhost:1935/live`
   - Stream Key: `my_awesome_stream`

2. **Automatic Results**:
   - Directories created automatically
   - Transcoding starts immediately
   - Available at: http://localhost:3000

### Stream with FFmpeg
```bash
# Test stream
ffmpeg -re -i test_video.mp4 -c copy -f flv rtmp://localhost:1935/live/test_stream

# Watch stream
ffplay http://localhost:8085/hls/test_stream/master.m3u8
```

### Multiple Concurrent Streams
```bash
# Stream 1
ffmpeg -re -i video1.mp4 -c copy -f flv rtmp://localhost:1935/live/stream1 &

# Stream 2  
ffmpeg -re -i video2.mp4 -c copy -f flv rtmp://localhost:1935/live/stream2 &

# Stream 3
ffmpeg -re -i video3.mp4 -c copy -f flv rtmp://localhost:1935/live/stream3 &
```

All streams will be processed independently with their own directories and transcoding processes.

## 🧹 Maintenance & Cleanup

### Automatic Stream Cleanup
```bash
# View cleanup options
./docker/stream-cleanup.sh dry-run

# Normal cleanup (respects retention policy)
./docker/stream-cleanup.sh

# Aggressive cleanup
./docker/stream-cleanup.sh force
```

### Service Management

#### 🛑 Stop Services (Multiple Options)

**Option 1: Using Stop Script (Recommended)**
```bash
# Graceful shutdown of all services
./docker/stop-streamforge.sh

# Stop with volume cleanup
./docker/stop-streamforge.sh --volumes

# Stop with image cleanup
./docker/stop-streamforge.sh --images

# Stop with complete cleanup (volumes + images)
./docker/stop-streamforge.sh --all
```

**Option 2: Using Docker Compose**
```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down --volumes

# Stop and remove everything (containers, networks, volumes)
docker-compose down --volumes --remove-orphans

# Stop specific service
docker-compose stop transcoder

# Restart specific service
docker-compose restart nginx-rtmp
```

**Option 3: Using Docker Commands**
```bash
# Stop all StreamForge containers
docker stop $(docker ps -q --filter "name=streamforge")

# Remove all StreamForge containers
docker rm $(docker ps -aq --filter "name=streamforge")

# Stop specific container
docker stop streamforge-nginx-rtmp
docker stop streamforge-transcoder
```

#### 📊 Service Status & Logs
```bash
# View running services
docker-compose ps

# View all containers
docker ps

# View logs
docker-compose logs -f nginx-rtmp

# View all service logs
docker-compose logs -f
```

#### 🔄 Restart Services
```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart transcoder

# Restart with rebuild
docker-compose down
docker-compose up -d --build
```

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Service Ports
RTMP_PORT=1935
WEB_PORT=3000
TRANSCODER_PORT=8083

# Stream Management
MAX_CONCURRENT_STREAMS=10
HLS_RETENTION_HOURS=24
AUTO_CLEANUP_HLS=true

# Quality Settings
BITRATE_720P=2800
BITRATE_480P=1400
BITRATE_360P=800
```

### Production Optimization
```bash
# Run production optimization
sudo ./docker/optimize-production.sh
```

## 🚨 Troubleshooting

### Common Issues
1. **Services won't start**: Check `docker-compose logs`
2. **Streams not transcoding**: Verify `curl http://localhost:8083/health`
3. **Permission issues**: Run `sudo chown -R $USER:$USER /tmp/streamforge`
4. **Port conflicts**: Modify ports in `.env` file

### Debug Mode
```bash
export DEBUG_MODE=true
export LOG_LEVEL=debug
docker-compose down && docker-compose up -d
```

## 📁 File Structure Created

```
StreamForge/
├── docker-compose.yml           # Main orchestration
├── .env                        # Environment configuration
├── setup-docker.sh            # Initial setup script
├── docker/
│   ├── start-streamforge.sh    # Main deployment script
│   ├── stop-streamforge.sh     # Graceful shutdown
│   ├── health-monitor.sh       # Health checking
│   ├── stream-cleanup.sh       # Automatic cleanup
│   ├── validate-deployment.sh  # Deployment validation
│   ├── optimize-production.sh  # Production tuning
│   └── nginx-web.conf          # Web server config
├── services/
│   ├── nginx-rtmp/
│   │   ├── Dockerfile          # Enhanced NGINX-RTMP
│   │   ├── nginx-enhanced.conf # Dynamic stream config
│   │   ├── on_publish.sh       # Stream start handler
│   │   ├── on_publish_done.sh  # Stream end handler
│   │   ├── transcode-enhanced.sh # Multi-quality transcoding
│   │   └── health-check.sh     # Health monitoring
│   ├── transcoder/Dockerfile   # Optimized Go transcoder
│   ├── hls-server/Dockerfile   # Optimized Go HLS server
│   ├── admin-api/Dockerfile    # Optimized Go admin API
│   └── stream-manager/Dockerfile # Go stream manager
└── DOCKER_DEPLOYMENT.md       # Complete documentation
```

## 🎉 Success Indicators

After running `./docker/start-streamforge.sh`, you should see:

✅ All Docker services running  
✅ Health endpoints responding  
✅ RTMP server listening on port 1935  
✅ Web interface accessible at http://localhost:3000  
✅ Dynamic directory creation working  
✅ API endpoints functional  
✅ Concurrent stream support verified  

**The platform is now ready for production live streaming with full dynamic stream management!** 🚀
