# StreamForge Docker Setup

## 🐳 Complete Containerized Streaming Platform

This directory contains a comprehensive Docker setup for StreamForge that provides:

- **One-command deployment** of the entire streaming platform
- **Dynamic stream management** with automatic directory creation
- **Multi-quality adaptive bitrate streaming** (720p, 480p, 360p)
- **Concurrent stream support** for multiple simultaneous streams
- **Automatic cleanup** and retention policies
- **Production-ready optimizations** and monitoring

## 📁 Directory Structure

```
docker/
├── README.md                    # This file
├── start-streamforge.sh         # Main deployment script
├── stop-streamforge.sh          # Graceful shutdown script
├── health-monitor.sh            # Comprehensive health checking
├── stream-cleanup.sh            # Automatic stream cleanup
├── optimize-production.sh       # Production optimization
└── nginx-web.conf              # Web server configuration
```

## 🚀 Quick Start

### 1. Deploy StreamForge

```bash
# Make scripts executable
chmod +x docker/*.sh

# Deploy the entire platform
./docker/start-streamforge.sh
```

### 2. Verify Deployment

```bash
# Check service health
./docker/health-monitor.sh

# View service status
docker-compose ps
```

### 3. Start Streaming

- **RTMP URL**: `rtmp://localhost:1935/live/{your_stream_key}`
- **Web Interface**: http://localhost:3000
- **HLS Playback**: http://localhost:8085/hls/{your_stream_key}/master.m3u8

## 🏗️ Architecture Components

### Core Services

1. **NGINX-RTMP Server** (`nginx-rtmp`)
   - RTMP ingestion on port 1935
   - HTTP serving on port 8080
   - Dynamic stream lifecycle management
   - Automatic transcoding triggers

2. **Transcoder Service** (`transcoder`)
   - Go-based transcoding service on port 8083
   - Multi-quality adaptive bitrate encoding
   - Dynamic stream detection and processing
   - RESTful API for stream management

3. **HLS Server** (`hls-server`)
   - Optimized HLS file serving on port 8085
   - CORS-enabled for web playback
   - Real-time stream discovery
   - Performance-optimized caching

4. **Admin API** (`admin-api`)
   - System monitoring on port 9000
   - Stream statistics and management
   - Resource usage monitoring
   - Health check endpoints

5. **Web Interface** (`web-interface`)
   - User-friendly interface on port 3000
   - Stream selection and playback
   - Real-time stream status
   - Responsive design

6. **Stream Manager** (`stream-manager`)
   - Advanced stream lifecycle management on port 8081
   - Concurrent stream coordination
   - Event-driven stream processing
   - Integration with other services

### Dynamic Stream Management Features

#### Automatic Directory Creation
When a new stream is published to `rtmp://localhost:1935/live/{stream_key}`:

```
/tmp/hls_shared/{stream_key}/
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

#### Stream Lifecycle Management
- **Stream Start**: Automatic directory creation and transcoding
- **Stream Active**: Continuous multi-quality encoding
- **Stream End**: Graceful cleanup and retention policy application
- **Concurrent Streams**: Independent processing for each stream

## 🔧 Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Service Ports
RTMP_PORT=1935
WEB_PORT=3000
TRANSCODER_PORT=8083
HLS_SERVER_PORT=8085
ADMIN_API_PORT=9000

# Storage Configuration
HLS_DIR=/tmp/streamforge/hls
RECORDINGS_DIR=/tmp/streamforge/recordings
LOGS_DIR=./logs

# Performance Settings
NGINX_WORKER_PROCESSES=auto
GIN_MODE=release

# Stream Management
MAX_CONCURRENT_STREAMS=10
HLS_RETENTION_HOURS=24
AUTO_CLEANUP_HLS=true

# Quality Settings
BITRATE_720P=2800
BITRATE_480P=1400
BITRATE_360P=800
AUDIO_BITRATE=128
```

### Volume Mounts

```yaml
volumes:
  hls_shared:     # HLS output files
  recordings:     # Stream recordings
  logs:          # Service logs
```

### Network Configuration

```yaml
networks:
  streamforge:
    driver: bridge
    subnet: 172.20.0.0/16
```

## 📊 Monitoring and Health Checks

### Health Monitoring Script

```bash
./docker/health-monitor.sh
```

Checks:
- ✅ Docker service status
- ✅ Health endpoint responses
- ✅ RTMP server availability
- ✅ Dynamic directory creation capability
- ✅ Transcoder API functionality
- ✅ Stream discovery capability
- ✅ Concurrent stream support
- ✅ System resource usage
- ✅ Active stream status

### Service Health Endpoints

| Service | Health Endpoint |
|---------|----------------|
| Transcoder | http://localhost:8083/health |
| HLS Server | http://localhost:8085/health |
| Admin API | http://localhost:9000/health |
| NGINX-RTMP | http://localhost:8080/health |

## 🧹 Maintenance

### Stream Cleanup

```bash
# Dry run (preview what would be cleaned)
./docker/stream-cleanup.sh dry-run

# Normal cleanup
./docker/stream-cleanup.sh

# Aggressive cleanup
./docker/stream-cleanup.sh force
```

### Service Management

```bash
# Stop all services
./docker/stop-streamforge.sh

# Stop with volume cleanup
./docker/stop-streamforge.sh --volumes

# Stop with image cleanup
./docker/stop-streamforge.sh --images

# Stop with complete cleanup
./docker/stop-streamforge.sh --all
```

### Log Management

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f transcoder

# View recent logs
docker-compose logs --tail=100 nginx-rtmp
```

## 🚀 Production Deployment

### 1. System Optimization

```bash
sudo ./docker/optimize-production.sh
```

This script:
- Optimizes kernel parameters for streaming
- Configures system limits for high concurrency
- Sets up Docker for production use
- Configures log rotation
- Sets up basic monitoring

### 2. Security Considerations

- Change default secrets in `.env`
- Configure firewall rules
- Set up SSL/TLS certificates
- Implement authentication
- Regular security updates

### 3. Performance Tuning

- Monitor resource usage
- Adjust worker processes
- Configure CDN for distribution
- Set up load balancing
- Optimize storage I/O

## 🔍 Troubleshooting

### Common Issues

1. **Services won't start**
   ```bash
   # Check Docker status
   sudo systemctl status docker
   
   # Check port conflicts
   sudo lsof -i :1935 -i :3000 -i :8080
   
   # Check logs
   docker-compose logs
   ```

2. **Streams not transcoding**
   ```bash
   # Check transcoder health
   curl http://localhost:8083/health
   
   # Check NGINX RTMP stats
   curl http://localhost:8080/stat
   
   # Check transcoder logs
   docker-compose logs transcoder
   ```

3. **Permission issues**
   ```bash
   # Fix directory permissions
   sudo chown -R $USER:$USER /tmp/streamforge
   sudo chmod -R 755 /tmp/streamforge
   ```

4. **High resource usage**
   ```bash
   # Check system resources
   ./docker/health-monitor.sh
   
   # Clean up old streams
   ./docker/stream-cleanup.sh force
   
   # Restart services
   docker-compose restart
   ```

### Debug Mode

```bash
# Enable debug logging
export DEBUG_MODE=true
export LOG_LEVEL=debug

# Restart with debug
docker-compose down
docker-compose up -d
```

## 📈 Scaling

### Horizontal Scaling

For high-load scenarios:

1. **Load Balancer**: Use NGINX or HAProxy
2. **Multiple Transcoders**: Scale transcoder service
3. **Distributed Storage**: Use shared storage for HLS files
4. **CDN Integration**: Distribute HLS content globally

### Vertical Scaling

- Increase CPU cores for transcoding
- Add more RAM for concurrent streams
- Use faster storage (SSD/NVMe)
- Optimize network bandwidth

## 🔄 Updates

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
./docker/start-streamforge.sh
```

## 📞 Support

For issues:
1. Check this documentation
2. Run health monitoring: `./docker/health-monitor.sh`
3. Check service logs: `docker-compose logs`
4. Review troubleshooting section
5. Check GitHub issues
