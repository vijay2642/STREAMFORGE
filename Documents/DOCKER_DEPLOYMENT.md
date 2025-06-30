# StreamForge Docker Deployment Guide

## 🚀 One-Command Deployment

StreamForge provides a complete Docker-based deployment solution that handles all dependencies, configuration, and service orchestration automatically.

### Quick Start

```bash
# Clone the repository
git clone https://github.com/vijay2642/STREAMFORGE.git
cd STREAMFORGE

# Make scripts executable
chmod +x docker/*.sh

# Deploy the entire platform
./docker/start-streamforge.sh
```

That's it! The entire StreamForge platform will be running and ready to handle live streams.

## 📋 Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **System Requirements**:
  - CPU: 4+ cores recommended
  - RAM: 8GB+ recommended
  - Storage: 50GB+ available space
  - Network: Stable internet connection

### Installation Commands

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose-plugin

# CentOS/RHEL
sudo yum install docker docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (optional)
sudo usermod -aG docker $USER
```

## 🏗️ Architecture Overview

The Docker deployment includes:

- **NGINX-RTMP Server**: Handles RTMP ingestion and HTTP serving
- **Transcoder Service**: Multi-quality adaptive bitrate transcoding
- **HLS Server**: Optimized HLS file serving with CORS support
- **Admin API**: System monitoring and management
- **Web Interface**: User-friendly streaming interface
- **Stream Manager**: Advanced stream lifecycle management

## 🔧 Configuration

### Environment Variables

Copy and customize the environment file:

```bash
cp .env.example .env
nano .env
```

Key configuration options:

```bash
# Service Ports
RTMP_PORT=1935          # RTMP ingestion
WEB_PORT=3000           # Web interface
TRANSCODER_PORT=8083    # Transcoder API

# Storage Directories
HLS_DIR=/tmp/streamforge/hls
RECORDINGS_DIR=/tmp/streamforge/recordings

# Performance Settings
NGINX_WORKER_PROCESSES=auto
GIN_MODE=release

# Stream Management
MAX_CONCURRENT_STREAMS=10
HLS_RETENTION_HOURS=24
AUTO_CLEANUP_HLS=true
```

### Production Optimization

For production deployments, run the optimization script:

```bash
sudo ./docker/optimize-production.sh
```

This script:
- Optimizes kernel parameters for streaming
- Configures system limits
- Sets up Docker for production
- Configures log rotation
- Sets up monitoring

## 🎬 Dynamic Stream Management

StreamForge automatically handles:

### 1. Automatic Directory Creation
When a stream starts at `rtmp://localhost:1935/live/{stream_key}`:
- Creates `/tmp/hls_shared/{stream_key}/720p/`
- Creates `/tmp/hls_shared/{stream_key}/480p/`
- Creates `/tmp/hls_shared/{stream_key}/360p/`
- Generates master playlist

### 2. Dynamic Transcoding
- Automatically detects new streams
- Starts multi-quality transcoding
- No service restarts required

### 3. Stream Lifecycle Management
- Proper cleanup when streams end
- Configurable retention policies
- Automatic segment cleanup

### 4. Concurrent Stream Support
- Handles multiple simultaneous streams
- Independent transcoding processes
- Isolated output directories

## 📊 Service Endpoints

After deployment, access these endpoints:

| Service | URL | Description |
|---------|-----|-------------|
| Web Interface | http://localhost:3000 | Main streaming interface |
| RTMP Ingestion | rtmp://localhost:1935/live/{key} | Stream publishing |
| HLS Playback | http://localhost:8085/hls/{key}/master.m3u8 | Stream viewing |
| Admin API | http://localhost:9000/health | System monitoring |
| Transcoder API | http://localhost:8083/health | Transcoding status |
| NGINX Stats | http://localhost:8080/stat | RTMP statistics |

## 🔍 Monitoring and Health Checks

### Health Monitoring

```bash
# Run comprehensive health check
./docker/health-monitor.sh

# Check service status
docker-compose ps

# View service logs
docker-compose logs -f [service_name]
```

### Stream Monitoring

```bash
# List active streams
curl http://localhost:8085/streams

# Check transcoder status
curl http://localhost:8083/transcode/active

# View NGINX statistics
curl http://localhost:8080/stat
```

## 🧹 Maintenance

### Stream Cleanup

```bash
# Manual cleanup (dry run)
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

# Stop with cleanup
./docker/stop-streamforge.sh --all

# Restart specific service
docker-compose restart transcoder

# View logs
docker-compose logs -f nginx-rtmp
```

### Updates and Maintenance

```bash
# Update images
docker-compose pull
docker-compose up -d

# Rebuild services
docker-compose build --no-cache
docker-compose up -d
```

## 🔧 Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check port usage
   sudo lsof -i :1935 -i :3000 -i :8080
   
   # Modify ports in .env file
   nano .env
   ```

2. **Permission Issues**
   ```bash
   # Fix directory permissions
   sudo chown -R $USER:$USER /tmp/streamforge
   sudo chmod -R 755 /tmp/streamforge
   ```

3. **Service Health Issues**
   ```bash
   # Check service health
   ./docker/health-monitor.sh
   
   # Restart unhealthy services
   docker-compose restart [service_name]
   ```

4. **Storage Issues**
   ```bash
   # Check disk space
   df -h /tmp/streamforge
   
   # Clean up old streams
   ./docker/stream-cleanup.sh force
   ```

### Debug Mode

Enable debug logging:

```bash
# Set debug environment
export DEBUG_MODE=true
export LOG_LEVEL=debug

# Restart services
docker-compose down
docker-compose up -d
```

## 📝 Example Usage

### Streaming with OBS Studio

1. **RTMP Settings**:
   - Server: `rtmp://localhost:1935/live`
   - Stream Key: `my_stream`

2. **Playback URLs**:
   - Master Playlist: `http://localhost:8085/hls/my_stream/master.m3u8`
   - 720p: `http://localhost:8085/hls/my_stream/720p/playlist.m3u8`
   - 480p: `http://localhost:8085/hls/my_stream/480p/playlist.m3u8`
   - 360p: `http://localhost:8085/hls/my_stream/360p/playlist.m3u8`

### Testing with FFmpeg

```bash
# Test stream publishing
ffmpeg -re -i test_video.mp4 -c copy -f flv rtmp://localhost:1935/live/test_stream

# Test playback
ffplay http://localhost:8085/hls/test_stream/master.m3u8
```

## 🚨 Production Considerations

1. **Security**:
   - Configure firewall rules
   - Set up SSL/TLS certificates
   - Implement authentication
   - Change default secrets

2. **Performance**:
   - Run optimization script
   - Monitor resource usage
   - Configure load balancing
   - Set up CDN for distribution

3. **Backup**:
   - Regular configuration backups
   - Stream recording policies
   - Database backups (if applicable)

4. **Monitoring**:
   - Set up alerting
   - Log aggregation
   - Performance metrics
   - Health check automation

## 📞 Support

For issues and questions:
- Check the troubleshooting section
- Review service logs
- Run health monitoring
- Check GitHub issues

## 🔄 Updates

To update StreamForge:

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
./docker/start-streamforge.sh
```
