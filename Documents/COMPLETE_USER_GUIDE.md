# 📺 StreamForge - Complete User Guide
*Your own YouTube-like streaming platform in minutes!*

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Streaming with OBS](#streaming-with-obs)
5. [Watching Streams](#watching-streams)
6. [Management & Monitoring](#management--monitoring)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)
9. [Complete Cleanup](#complete-cleanup)

---

## 🔧 Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu/Debian recommended) or macOS
- **RAM**: Minimum 4GB (8GB recommended)
- **Storage**: 20GB free space
- **CPU**: 2+ cores (4+ recommended for multiple streams)

### Software Requirements
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 1.29 or higher
- **Git**: For cloning the repository
- **OBS Studio**: For streaming (free download from [obsproject.com](https://obsproject.com))

### Network Requirements
- **Ports**: The following ports must be available:
  - `1935` - RTMP streaming
  - `3000` - Web interface
  - `8080` - NGINX stats
  - `8083` - Transcoder API
  - `8085` - HLS streaming server
  - `8081` - Stream manager (optional)
  - `9000` - Admin API

---

## 📦 Installation

### Step 1: Clone the Repository
```bash
# Clone StreamForge
git clone https://github.com/yourusername/streamforge.git
cd streamforge

# Or if you have a zip file
unzip streamforge.zip
cd STREAMFORGE
```

### Step 2: Set Permissions
```bash
# Make scripts executable
chmod +x start.sh stop.sh scripts/*.sh
```

### Step 3: Create Required Directories
The `start.sh` script handles this automatically, but if needed:
```bash
# Create directories
mkdir -p /tmp/streamforge/hls
mkdir -p /tmp/streamforge/recordings
mkdir -p ./logs

# Set permissions
chmod -R 777 /tmp/streamforge
chmod -R 777 ./logs
```

---

## 🚀 Quick Start

### 1️⃣ Start StreamForge (One Command!)
```bash
./start.sh
```

This single command:
- ✅ Cleans up old data
- ✅ Creates necessary directories
- ✅ Sets proper permissions
- ✅ Builds all Docker containers
- ✅ Starts all services
- ✅ Launches auto-transcoding monitor
- ✅ Displays all access URLs

**Expected Output:**
```
🚀 Starting StreamForge with automated setup...
🛑 Stopping existing containers...
🧹 Cleaning up old data...
🔧 Initializing permissions...
🔨 Building services...
🚀 Starting all services...
⏳ Waiting for services to start...
🏥 Checking service health...
✅ StreamForge is ready!

📺 Access points:
   Web Interface: http://localhost:3000
   RTMP Server:   rtmp://localhost:1935/live
   HLS Server:    http://localhost:8085/hls/
   Admin API:     http://localhost:9000

🔄 Starting auto-transcode monitor...
✅ Auto-transcode monitor started (PID: 12345)

Transcoding will start automatically when you begin streaming!
```

### 2️⃣ Verify Everything is Running
```bash
# Check all services
docker-compose ps

# Should show:
# streamforge-nginx-rtmp     Up (healthy)
# streamforge-transcoder     Up (healthy)
# streamforge-hls-server     Up (healthy)
# streamforge-admin-api      Up (healthy)
# streamforge-web            Up (healthy)
```

### 3️⃣ Open Web Interface
Open your browser and go to: **http://localhost:3000**

---

## 📡 Streaming with OBS

### Basic OBS Setup

1. **Open OBS Studio**

2. **Go to Settings → Stream**

3. **Configure these settings:**
   - **Service**: `Custom...`
   - **Server**: `rtmp://localhost:1935/live`
     - For remote server: `rtmp://YOUR_SERVER_IP:1935/live`
   - **Stream Key**: Choose any name (e.g., `stream1`, `myshow`, `gaming`)
     - ⚠️ Avoid spaces or special characters
     - ✅ Good: `stream1`, `my-show`, `gaming_channel`
     - ❌ Bad: `my stream`, `stream#1`, `my@show`

4. **Click OK to save**

5. **Add your sources** (webcam, screen capture, etc.)

6. **Click "Start Streaming"**

### What Happens Automatically

When you start streaming:
1. 🎥 NGINX-RTMP receives your stream
2. 🤖 Auto-transcode monitor detects the new stream
3. 🎬 Transcoding starts automatically (720p, 480p, 360p)
4. 📺 Stream becomes available on the web player
5. 🌐 HLS files are generated for adaptive streaming

### Multiple Simultaneous Streams

You can run multiple streams at once:
- **Stream 1**: OBS with stream key `camera1`
- **Stream 2**: FFmpeg with stream key `screen1`
- **Stream 3**: Another OBS with stream key `event1`

Each stream gets its own:
- Transcoding pipeline
- HLS directory
- Quality variants

---

## 👀 Watching Streams

### Method 1: Web Interface (Easiest)

1. **Open browser**: http://localhost:3000
2. **Select stream** from dropdown
3. **Click Play**

Features:
- 🎯 Adaptive bitrate (auto quality selection)
- 📱 Mobile responsive
- 🎮 Keyboard controls

### Method 2: Direct HLS URL

For custom players or apps:
```
http://localhost:8085/hls/STREAM_NAME/master.m3u8
```

Example:
```
http://localhost:8085/hls/stream1/master.m3u8
```

### Method 3: VLC Media Player

1. Open VLC
2. Media → Open Network Stream
3. Enter: `http://localhost:8085/hls/stream1/master.m3u8`
4. Click Play

### Method 4: React/Web App Integration

```javascript
// Example for video.js
const player = videojs('my-video', {
  sources: [{
    src: 'http://localhost:8085/hls/stream1/master.m3u8',
    type: 'application/x-mpegURL'
  }],
  html5: {
    hls: {
      overrideNative: true
    }
  }
});
```

⚠️ **Important**: Use port **8085** for HLS, not 8083!

---

## 🔧 Management & Monitoring

### Check Active Streams
```bash
# View all active transcoders
curl http://localhost:8083/transcode/active | jq

# Check RTMP statistics
curl http://localhost:8080/stat

# Monitor auto-transcode logs
tail -f logs/auto-transcode.log
```

### Service Health Checks
```bash
# Check all services
docker-compose ps

# Individual health endpoints
curl http://localhost:8083/health     # Transcoder
curl http://localhost:8085/health     # HLS Server
curl http://localhost:9000/health     # Admin API
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f transcoder
docker-compose logs -f nginx-rtmp

# Auto-transcode monitor
tail -f logs/auto-transcode.log
```

### Manual Stream Control (if needed)
```bash
# Start transcoding manually
curl -X POST http://localhost:8083/transcode/start/stream1

# Stop transcoding
curl -X POST http://localhost:8083/transcode/stop/stream1

# Check specific stream status
curl http://localhost:8083/transcode/status/stream1
```

---

## 🆘 Troubleshooting

### Common Issues & Solutions

#### "Can't connect to RTMP server"
```bash
# 1. Check if NGINX-RTMP is running
docker-compose ps nginx-rtmp

# 2. Check firewall
sudo ufw status
sudo ufw allow 1935/tcp  # If needed

# 3. Test with FFmpeg
ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 \
       -c:v libx264 -preset veryfast \
       -f flv rtmp://localhost:1935/live/test
```

#### "Stream not appearing in web player"
```bash
# 1. Check if stream is being received
curl http://localhost:8080/stat | grep "stream1"

# 2. Check if transcoding started
curl http://localhost:8083/transcode/active

# 3. Check auto-transcode monitor
ps aux | grep auto-transcode
tail -f logs/auto-transcode.log

# 4. Restart auto-transcode if needed
kill $(cat logs/auto-transcode.pid)
nohup ./scripts/auto-transcode.sh > ./logs/auto-transcode.log 2>&1 &
```

#### "HLS files not being created"
```bash
# 1. Check permissions
ls -la /tmp/streamforge/hls/

# 2. Fix permissions if needed
sudo chmod -R 777 /tmp/streamforge/hls/

# 3. Check transcoder logs
docker-compose logs --tail=50 transcoder | grep ERROR

# 4. Test FFmpeg inside container
docker exec streamforge-transcoder ffmpeg -version
```

#### "Seeing old/stale streams"
```bash
# Complete cleanup and restart
./stop.sh
rm -rf /tmp/streamforge/*
./start.sh
```

---

## ⚙️ Advanced Configuration

### Environment Variables

Create `.env` file for custom settings:
```bash
# Ports
RTMP_PORT=1935
WEB_PORT=3000
HLS_SERVER_PORT=8085
TRANSCODER_PORT=8083

# Directories
HLS_DIR=/tmp/streamforge/hls
RECORDINGS_DIR=/tmp/streamforge/recordings
LOGS_DIR=./logs

# Performance
NGINX_WORKER_PROCESSES=auto
GIN_MODE=release
```

### Custom Transcoding Profiles

Edit transcoding settings in the transcoder configuration:
- **High Quality**: 1080p @ 5Mbps
- **Medium Quality**: 720p @ 2.5Mbps  
- **Low Quality**: 480p @ 1Mbps
- **Mobile**: 360p @ 600Kbps

### Security Considerations

For production deployment:
1. **Change default ports**
2. **Add authentication to RTMP**
3. **Use HTTPS for web interface**
4. **Implement stream keys validation**
5. **Set up firewall rules**
6. **Use reverse proxy (nginx/caddy)**

---

## 🧹 Complete Cleanup

### Stop Everything
```bash
./stop.sh
```

### Remove All Data
```bash
# Stop services
./stop.sh

# Remove containers and volumes
docker-compose down -v

# Clean directories
rm -rf /tmp/streamforge/*
rm -rf ./logs/*

# Remove Docker images (optional)
docker-compose down --rmi all
```

### Fresh Start
After cleanup, simply run:
```bash
./start.sh
```

---

## 📊 Performance Tips

1. **CPU Usage**
   - Each stream uses ~1 CPU core for transcoding
   - Adjust quality settings if CPU is high

2. **Storage**
   - HLS segments are automatically cleaned
   - Monitor `/tmp/streamforge/` size

3. **Network**
   - Each viewer uses ~2-3 Mbps bandwidth
   - Consider CDN for many viewers

4. **Scaling**
   - Can handle 5-10 simultaneous streams on 8-core CPU
   - Add more transcoders for horizontal scaling

---

## 🎯 Example Workflows

### Live Event Streaming
```bash
# 1. Start platform
./start.sh

# 2. Configure OBS
# Server: rtmp://localhost:1935/live
# Key: live-event-2024

# 3. Share link with viewers
# http://yourserver.com:3000

# 4. Monitor
watch curl -s http://localhost:8083/transcode/active
```

### Multi-Camera Setup
```bash
# Camera 1 (OBS)
# Stream Key: camera-main

# Camera 2 (FFmpeg from IP camera)
ffmpeg -i rtsp://camera2.local:554/stream \
       -c:v libx264 -preset veryfast \
       -f flv rtmp://localhost:1935/live/camera-side

# Both streams auto-transcoded and available
```

### 24/7 Streaming
```bash
# Use FFmpeg in a loop
while true; do
  ffmpeg -re -i /path/to/playlist.m3u8 \
         -c copy -f flv rtmp://localhost:1935/live/247-channel
  sleep 1
done
```

---

## 🆔 Quick Reference Card

### URLs
- **Web Player**: http://localhost:3000
- **RTMP Ingest**: rtmp://localhost:1935/live
- **HLS Output**: http://localhost:8085/hls/{stream}/master.m3u8
- **Stats**: http://localhost:8080/stat
- **API**: http://localhost:8083/transcode/active

### Commands
```bash
./start.sh              # Start everything
./stop.sh               # Stop everything
docker-compose ps       # Check status
docker-compose logs -f  # View logs
```

### OBS Settings
- **Server**: rtmp://localhost:1935/live
- **Stream Key**: your-stream-name

---

## 🎉 That's It!

You now have a fully automated streaming platform that:
- ✅ Auto-detects new streams
- ✅ Auto-starts transcoding
- ✅ Auto-manages permissions
- ✅ Auto-cleans old data
- ✅ Works with any RTMP source

**Happy Streaming!** 🚀

---

*For issues or questions, check the logs first, then refer to the troubleshooting section.*