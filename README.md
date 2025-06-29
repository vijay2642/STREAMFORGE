# 🚀 StreamForge - High-Performance Live Streaming Platform

**Production-ready live streaming platform built with Go for maximum performance**

[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go)](https://golang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)](https://docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Features

- **🚀 Pure Go Performance** - Zero Python overhead for maximum speed
- **📺 Adaptive Bitrate** - Automatic 720p/480p/360p quality scaling  
- **⚡ Low Latency** - 6-second target latency for live streaming
- **🔄 Auto Transcoding** - Real-time FFmpeg transcoding with H.264 optimization
- **📊 Real-time Monitoring** - Comprehensive admin dashboard and APIs
- **🌐 HLS Streaming** - Industry-standard HTTP Live Streaming
- **🎛️ Stream Management** - Start/stop/restart streams via API
- **📈 Analytics** - Stream statistics, disk usage, system metrics

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OBS Studio    │────│  NGINX-RTMP     │────│   Transcoder    │
│   (RTMP Input)  │    │   (Port 1935)   │    │   (Go Service)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐              │
│   Web Players   │────│   HLS Server    │──────────────┘
│   (HLS Output)  │    │   (Go Service)  │
└─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐
│  Admin Panel    │────│   Admin API     │
│  (Management)   │    │   (Go Service)  │
└─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y docker.io docker-compose git golang-go ffmpeg curl

# CentOS/RHEL  
sudo yum install -y docker docker-compose git golang ffmpeg curl
```

### 1. Clone & Setup
```bash
git clone <your-repo-url> /root/STREAMFORGE
cd /root/STREAMFORGE
chmod +x scripts/*.sh *.sh
```

### 2. Start All Services (One Command!)
```bash
./scripts/start-go-services.sh
```

### 3. Start NGINX-RTMP
```bash
docker-compose up -d nginx-rtmp
```

### 4. Verify Setup
```bash
./scripts/verify-setup.sh
```

**Expected Output:**
```
✅ 🎉 StreamForge is ready for streaming!
```

## 🎬 Start Streaming

### OBS Studio Setup
1. **Stream Settings:**
   - **Server**: `rtmp://localhost:1935/live`
   - **Stream Key**: `mystream` (any name you want)
2. **Click "Start Streaming"**

### Watch Your Stream
- **Master Playlist**: `http://localhost:8085/hls/mystream/master.m3u8`
- **VLC**: Open Network Stream → Use master playlist URL
- **Web**: `http://localhost:8085/streams` (stream browser)

## 📊 Management & Monitoring

### Service Endpoints
- **Transcoder API**: `http://localhost:8083`
- **HLS File Server**: `http://localhost:8085`  
- **Admin API**: `http://localhost:9000`
- **NGINX Stats**: `http://localhost:8080/stat`

### Health Checks
```bash
curl http://localhost:8083/health  # Transcoder
curl http://localhost:8085/health  # HLS Server
curl http://localhost:9000/health  # Admin API
curl http://localhost:8080/health  # NGINX
```

### Admin APIs
- **Active Streams**: `GET /api/admin/streams`
- **Disk Usage**: `GET /api/admin/disk-usage`  
- **System Stats**: `GET /api/admin/stats`
- **File Management**: `GET /api/admin/files`
- **Cleanup**: `POST /api/admin/cleanup`

## 🔧 Configuration

### Service Ports
| Service | Port | Purpose |
|---------|------|---------|
| RTMP Input | 1935 | OBS/FFmpeg streaming |
| NGINX HTTP | 8080 | Stats & control |
| Transcoder API | 8083 | Stream management |
| HLS Server | 8085 | File serving |
| Admin API | 9000 | Administration |

### Quality Profiles
| Quality | Resolution | Video Bitrate | Audio Bitrate | H.264 Profile |
|---------|------------|---------------|---------------|---------------|
| 720p | 1280x720 | 2800k | 128k | Main 3.1 |
| 480p | 854x480 | 1400k | 96k | Main 3.1 |
| 360p | 640x360 | 800k | 64k | Baseline 3.0 |

### HLS Settings
- **Segment Duration**: 2 seconds
- **Playlist Window**: 6 segments (12s buffer)
- **Target Latency**: 6 seconds
- **GOP Size**: 60 frames (perfect 2s alignment)

## 🛠️ Development

### Build Services
```bash
# Individual services
cd services/transcoder && go build -o transcoder .
cd services/hls-server && go build -o hls-server .
cd services/admin-api && go build -o admin-api .

# Or use the startup script (auto-builds)
./scripts/start-go-services.sh
```

### Project Structure
```
StreamForge/
├── services/
│   ├── transcoder/          # Go transcoding service
│   ├── hls-server/          # Go HLS file server
│   ├── admin-api/           # Go admin API
│   └── nginx-rtmp/          # NGINX-RTMP Docker config
├── scripts/
│   ├── start-go-services.sh # Main startup script
│   └── verify-setup.sh      # Setup verification
├── logs/                    # Service logs
└── docker-compose.yml       # NGINX-RTMP container
```

## 🔍 Troubleshooting

### Services Won't Start
```bash
# Kill old processes
sudo pkill -f "transcoder|hls-server|admin-api|python"

# Check ports
sudo lsof -i :8083 -i :8085 -i :9000 -i :1935 -i :8080

# Restart services  
./scripts/start-go-services.sh
```

### Check Logs
```bash
tail -f logs/transcoder.log
tail -f logs/hls-server.log
tail -f logs/admin-api.log
docker logs streamforge-nginx-rtmp-1
```

### Verify Streaming
```bash
# Should show .ts and .m3u8 files when streaming
ls -la /tmp/hls_shared/mystream/
```

## ⚡ Performance Optimizations

- **Pure Go Stack**: Eliminated Python bottlenecks
- **Zero-copy CORS**: Optimized headers for HLS
- **Smart Caching**: 5s for playlists, 2min for segments
- **FFmpeg Tuning**: Zerolatency preset with GOP alignment
- **HTTP/2 Ready**: Native support for modern protocols
- **Memory Efficient**: Go's garbage collection vs Python GIL

## 📝 API Examples

### Start Stream Transcoding
```bash
curl -X POST http://localhost:8083/api/streams/start/mystream
```

### Get Stream Status
```bash
curl http://localhost:8083/api/streams/status/mystream
```

### Check Disk Usage
```bash
curl http://localhost:9000/api/admin/disk-usage
```

### Get System Stats
```bash
curl http://localhost:9000/api/admin/stats
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Gin](https://github.com/gin-gonic/gin) web framework
- Powered by [FFmpeg](https://ffmpeg.org/) for transcoding
- Uses [NGINX-RTMP](https://github.com/arut/nginx-rtmp-module) for RTMP ingestion

---

**🚀 Ready to stream? Start with `./scripts/start-go-services.sh` and begin broadcasting!**