# 🚀 StreamForge Quick Start Guide

**High-Performance Go-Based Live Streaming Platform**

## Prerequisites (One-time setup)
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y docker.io docker-compose git golang-go ffmpeg curl

# CentOS/RHEL
sudo yum install -y docker docker-compose git golang ffmpeg curl
```

## 🎯 Quick Start (3 Commands)

### 1. Clone and Setup
```bash
git clone <your-repo-url> /root/STREAMFORGE
cd /root/STREAMFORGE
chmod +x scripts/*.sh *.sh
```

### 2. Start All Services
```bash
# This single command starts everything:
./scripts/start-go-services.sh
```
**Expected Output:**
```
✅ All Go services started successfully!
🌐 Service endpoints:
   - Transcoder API: http://localhost:8083
   - HLS File Server: http://localhost:8085  
   - Admin API: http://localhost:9000
```

### 3. Start NGINX-RTMP
```bash
docker-compose up -d nginx-rtmp
```

## 🎬 Start Streaming

### Option A: OBS Studio (Recommended)
1. **Stream Settings:**
   - **Server**: `rtmp://localhost:1935/live`
   - **Stream Key**: `mystream` (use any name)
2. **Click "Start Streaming"**

### Option B: Test Stream (FFmpeg)
```bash
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 \
       -f lavfi -i sine=frequency=1000 \
       -c:v libx264 -preset veryfast -b:v 2000k \
       -c:a aac -b:a 128k \
       -f flv rtmp://localhost:1935/live/mystream
```

## 📺 Watch Your Stream

### Stream URLs (replace 'mystream' with your stream key):
- **Master Playlist**: `http://localhost:8085/hls/mystream/master.m3u8`
- **720p Quality**: `http://localhost:8085/hls/mystream/720p/playlist.m3u8`
- **480p Quality**: `http://localhost:8085/hls/mystream/480p/playlist.m3u8`
- **360p Quality**: `http://localhost:8085/hls/mystream/360p/playlist.m3u8`

### VLC Player:
1. Open VLC → **Media** → **Open Network Stream**
2. URL: `http://localhost:8085/hls/mystream/master.m3u8`
3. **Play**

### Web Browser:
- Stream list: `http://localhost:8085/streams`
- Stream stats: `http://localhost:8085/stats/mystream`

## 📊 Monitoring & Management

### Health Checks:
```bash
curl http://localhost:8083/health  # Transcoder: {"status":"healthy"}
curl http://localhost:8085/health  # HLS Server: {"status":"healthy"}  
curl http://localhost:9000/health  # Admin API: {"status":"healthy"}
curl http://localhost:8080/health  # NGINX: "healthy"
```

### Admin Dashboard APIs:
- **Active Streams**: `http://localhost:9000/api/admin/streams`
- **Disk Usage**: `http://localhost:9000/api/admin/disk-usage`
- **System Stats**: `http://localhost:9000/api/admin/stats`
- **File Management**: `http://localhost:9000/api/admin/files`

## 🔧 Troubleshooting

### Services Won't Start:
```bash
# Check what's using the ports
sudo lsof -i :8083 -i :8085 -i :9000 -i :1935 -i :8080

# Kill old processes
sudo pkill -f "transcoder|hls-server|admin-api|python"

# Restart
./scripts/start-go-services.sh
```

### Check Logs:
```bash
tail -f logs/transcoder.log
tail -f logs/hls-server.log
tail -f logs/admin-api.log
docker logs streamforge-nginx-rtmp-1
```

### Verify Streaming:
```bash
# Should show .ts and .m3u8 files when streaming
ls -la /tmp/hls_shared/mystream/
```

## ⚡ Performance Features

- **Pure Go Stack**: Zero Python overhead
- **Low Latency**: 6-second target latency
- **Auto Quality**: 720p/480p/360p adaptive bitrate
- **Smart Caching**: Optimized for HLS delivery
- **Concurrent Streams**: Multiple streams supported

## 🎯 Quick Verification Checklist

- [ ] `./scripts/start-go-services.sh` completes successfully
- [ ] All 4 health checks return "healthy"  
- [ ] OBS connects to `rtmp://localhost:1935/live/mystream`
- [ ] VLC plays `http://localhost:8085/hls/mystream/master.m3u8`
- [ ] Files appear in `/tmp/hls_shared/mystream/`

## 🔄 Restart Everything:
```bash
# Stop services
sudo pkill -f "transcoder|hls-server|admin-api"
docker-compose down

# Start fresh
./scripts/start-go-services.sh
docker-compose up -d nginx-rtmp
```

## 📚 Service Ports Summary:
- **1935**: RTMP Input (for OBS/FFmpeg)
- **8080**: NGINX HTTP (stats, control)
- **8083**: Transcoder API (Go)
- **8085**: HLS File Server (Go)
- **9000**: Admin API (Go)

---
**That's it! Your high-performance streaming platform is ready! 🎉**