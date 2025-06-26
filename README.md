# StreamForge - Multi-Quality Live Streaming Platform

🎬 **Professional live streaming platform with adaptive multi-quality transcoding and HLS delivery.**

## 🚀 Quick Start

### Start Multi-Quality Adaptive Streaming
```bash
# Start adaptive streaming for your OBS streams
python3 bin/multi_quality_transcoder.py stream1 &
python3 bin/multi_quality_transcoder.py stream3 &

# Start CORS server for HLS delivery
python3 bin/cors_server.py &

# Start web server for player interface
cd web && python3 -m http.server 3000 --bind 0.0.0.0 &
```

### Access Your Streams
- **Adaptive Player**: `http://YOUR_IP:3000/adaptive-live-player.html`
- **Stream URLs**: `http://YOUR_IP:8085/stream1/master.m3u8`

## 📂 Project Structure

```
StreamForge/
├── bin/                    # Executable transcoders and servers
│   ├── multi_quality_transcoder.py  # Main adaptive transcoder
│   ├── live_transcoder.py          # Simple HLS transcoder
│   ├── buffer_fix_transcoder.py    # Optimized transcoder
│   └── cors_server.py              # HLS content server
├── web/                    # Web interface and players
│   ├── adaptive-live-player.html   # Main adaptive player
│   ├── test-player.html           # Simple test player
│   └── index.html                 # Stream dashboard
├── scripts/               # Utility scripts
│   ├── health/           # Health checks and startup scripts
│   └── deployment/       # Docker and cloud deployment
├── config/               # Configuration files
├── logs/                 # Application logs
├── docs/                 # Documentation
└── services/             # Service definitions
```

## 🎯 Features

- **Multi-Quality Adaptive Streaming**: 1080p, 720p, 480p, 360p
- **HLS.js Player**: Automatic quality adaptation
- **Live Transcoding**: Real-time RTMP to HLS conversion
- **CORS Support**: Cross-origin streaming
- **Health Monitoring**: System status checks
- **Docker Support**: Container deployment ready

## 🛠️ Health & Management

```bash
# Check system health
./scripts/health/health-check.sh

# Quick startup (auto-detects streams)
./scripts/health/streamforge-quick-start.sh

# Full platform startup
./scripts/health/streamforge-health-startup.sh

# Interactive debugging
python3 scripts/health/smart_debug.py
```

## 📺 OBS Studio Setup

**Stream Settings:**
- **Server**: `rtmp://YOUR_IP:1935/live`
- **Stream Key**: `stream1`, `stream2`, `stream3`, etc.

**Recommended Settings:**
- **Bitrate**: 3000-5000 kbps
- **Keyframe Interval**: 2 seconds
- **Profile**: High
- **Encoder**: x264

## 🌐 Architecture

1. **RTMP Ingestion** → NGINX RTMP Server (port 1935)
2. **Multi-Quality Transcoding** → FFmpeg with 4 quality levels
3. **HLS Delivery** → CORS Server (port 8085)
4. **Web Interface** → HTTP Server (port 3000)
5. **Adaptive Playback** → HLS.js Player

## 📊 Quality Levels

| Quality | Resolution | Bitrate | Use Case |
|---------|------------|---------|----------|
| 1080p   | 1920×1080  | 5 Mbps  | High-end streaming |
| 720p    | 1280×720   | 3 Mbps  | Standard HD |
| 480p    | 854×480    | 1.5 Mbps| Mobile/slow connections |
| 360p    | 640×360    | 800k    | Ultra-low bandwidth |

## 🚀 Deployment

See `docs/guides/` for detailed deployment guides:
- Cloud deployment (Railway, DigitalOcean)
- Docker containerization
- Kubernetes orchestration
- Load balancing and scaling

---

**Built with ❤️ for professional live streaming** 