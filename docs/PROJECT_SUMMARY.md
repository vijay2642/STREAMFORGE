# StreamForge - Live Streaming Platform Summary

## 🎯 Project Overview
StreamForge is a complete live streaming platform featuring RTMP ingestion, multi-quality transcoding, HLS delivery, and adaptive web players. The system supports real-time quality switching and automatic bitrate adaptation.

## 🏗️ Architecture

### Core Components
1. **NGINX RTMP Server** (Port 1935) - Stream ingestion
2. **FFmpeg Transcoders** - Multi-quality live transcoding  
3. **CORS Server** (Port 8085) - HLS content delivery
4. **Web Player** (Port 3000) - Adaptive streaming interface

### Stream Endpoints
- **RTMP Input**: `rtmp://188.245.163.8:1935/live/stream1` and `rtmp://188.245.163.8:1935/live/stream3`
- **HLS Output**: `http://188.245.163.8:8085/{stream}/master.m3u8`
- **Web Player**: `http://188.245.163.8:3000/adaptive-live-player.html`

## 📁 Project Structure

### Core Files
```
├── live_transcoder.py          # Single quality live transcoding
├── multi_quality_transcoder.py # Multi-quality adaptive transcoding
├── cors_server.py              # HLS content delivery server
├── userinput.py               # Interactive task loop interface
└── stream_config.json         # Stream configuration
```

### Health & Management Scripts
```
├── health-check.sh             # System health monitoring (read-only)
├── streamforge-quick-start.sh  # Smart auto-startup system
├── streamforge-health-startup.sh # Enterprise platform manager
├── smart_debug.py             # Automated debug console
└── debug.py                   # Interactive debug interface
```

### Web Interface
```
web/
├── adaptive-live-player.html   # Advanced adaptive streaming player
├── test-player.html           # Simple HLS test player
├── live-player.html           # Feature-rich live player
├── stream-admin.html          # Stream administration interface
└── index.html                 # Main web interface
```

### Infrastructure
```
├── docker-compose.yml         # Container orchestration
├── Makefile                   # Build and deployment automation
├── deploy-to-cloud.sh         # Cloud deployment script
└── services/                  # Microservice configurations
```

## 🚀 Quick Start

### 1. Health Check
```bash
./health-check.sh
```

### 2. Start All Services
```bash
./streamforge-quick-start.sh
```

### 3. Start Live Transcoding
```bash
# Single quality (basic)
python3 live_transcoder.py both

# Multi-quality (adaptive)
python3 multi_quality_transcoder.py both
```

### 4. Access Web Player
- Basic Player: `http://188.245.163.8:3000/test-player.html`
- Adaptive Player: `http://188.245.163.8:3000/adaptive-live-player.html`

## 🎬 Transcoding Options

### Single Quality (live_transcoder.py)
- **Output**: 720p @ 2Mbps
- **Segments**: 2-second duration, 10-segment buffer
- **Use Case**: Basic live streaming

### Multi-Quality (multi_quality_transcoder.py)
- **Qualities**: 1080p, 720p, 480p, 360p
- **Adaptive**: Automatic bitrate switching
- **Master Playlist**: HLS adaptive streaming
- **Use Case**: Professional adaptive streaming

## 🌐 Web Players

### Adaptive Live Player (adaptive-live-player.html)
- **Features**: Quality switching, bandwidth monitoring, buffer management
- **HLS.js**: Advanced streaming capabilities
- **UI**: Modern responsive design with real-time stats

### Test Player (test-player.html)
- **Features**: Basic HLS playback testing
- **Use Case**: Quick stream validation

## 📊 Quality Profiles

| Quality | Resolution | Video Bitrate | Audio Bitrate | Buffer Size |
|---------|------------|---------------|---------------|-------------|
| 1080p   | 1920x1080  | 5000k         | 128k          | 10000k      |
| 720p    | 1280x720   | 3000k         | 128k          | 6000k       |
| 480p    | 854x480    | 1500k         | 96k           | 3000k       |
| 360p    | 640x360    | 800k          | 64k           | 1600k       |

## 🔧 Management Tools

### Interactive Debug Console
```bash
python3 userinput.py
```
Provides interactive task loop for system management.

### Smart Debug System
```bash
python3 smart_debug.py
```
Automated health checks and issue resolution.

### Health Monitoring
```bash
./health-check.sh
```
Comprehensive system status (16 service checks).

## 🎯 Key Features

### Live Streaming
- ✅ Real-time RTMP ingestion
- ✅ Low-latency HLS delivery
- ✅ Rolling segment windows
- ✅ Live playlist management

### Quality Management
- ✅ Multi-bitrate transcoding
- ✅ Automatic quality adaptation
- ✅ Manual quality override
- ✅ Seamless switching

### Monitoring & Management
- ✅ Real-time health checks
- ✅ Automated startup/recovery
- ✅ Interactive debug console
- ✅ Comprehensive logging

### Web Interface
- ✅ Responsive adaptive player
- ✅ Real-time statistics
- ✅ Stream administration
- ✅ Quality controls

## 🔄 Workflow

1. **Stream Input**: RTMP publishers send to port 1935
2. **Transcoding**: FFmpeg generates multiple qualities
3. **Delivery**: CORS server serves HLS on port 8085
4. **Playback**: Web players consume adaptive streams
5. **Management**: Health checks and auto-recovery

## 🛠️ Development Commands

```bash
# Start single quality transcoding
python3 live_transcoder.py stream1

# Start multi-quality transcoding  
python3 multi_quality_transcoder.py both

# Start CORS server
python3 cors_server.py

# Run health check
./health-check.sh

# Quick start all services
./streamforge-quick-start.sh

# Interactive management
python3 userinput.py
```

## 📝 Notes

- **Cleaned Project**: Removed redundant transcoders, test files, and logs
- **Core Focus**: Live streaming with quality adaptation
- **Production Ready**: Health monitoring and auto-recovery
- **Scalable**: Docker-based deployment with cloud support

## 🎉 Success Metrics

- ✅ 93% System Health (15/16 services)
- ✅ Live streaming confirmed working
- ✅ Quality switching implemented
- ✅ Adaptive bitrate streaming functional
- ✅ Automated management tools operational 