# StreamForge Enhanced - Multi-Stream Live Player

This enhanced version of StreamForge addresses buffering issues, implements functional quality selection, and adds timeline seeking with DVR functionality for live streams.

## 🚀 Key Improvements

### 1. **Buffering Issues Fixed**
- **Go-based Transcoder**: Rewritten in Go for better concurrent stream handling
- **Optimized HLS Settings**: 2-second segments with proper buffer management
- **Enhanced NGINX Config**: Tuned for multiple concurrent streams
- **Low-latency Encoding**: Zero-latency tuning with proper GOP settings

### 2. **Functional Quality Selection**
- **True Backend Support**: Quality switching actually changes the transcoded stream
- **6 Quality Levels**: 1080p, 720p, 480p, 360p, 240p, 144p
- **Adaptive Bitrate**: Automatic quality adjustment based on bandwidth
- **Manual Override**: Users can lock to specific quality levels

### 3. **Timeline Seeking with DVR**
- **Historical Playback**: Scrub through past content of live streams
- **GO LIVE Button**: Manual return to live edge
- **Persistent History**: Maintains historical content for seeking
- **Visual Timeline**: Shows buffered content and current position

### 4. **Enhanced Live Player**
- **Multi-stream Support**: Up to 4 concurrent streams
- **Real-time Stats**: Buffer health, bitrate, latency monitoring
- **Stream Management**: Easy add/remove streams
- **Modern UI**: Clean, responsive interface

## 📁 Project Structure

```
STREAMFORGE/
├── web/
│   ├── live-player.html           # Enhanced multi-stream player
│   ├── index.html                 # Original player (preserved)
│   └── adaptive-live-player.html  # Adaptive player (preserved)
├── services/
│   ├── transcoder/                # Go transcoder service
│   │   ├── main.go
│   │   └── internal/
│   │       ├── transcoder/
│   │       │   └── manager.go     # Enhanced with optimized settings
│   │       └── handlers/
│   │           └── handlers.go
│   └── nginx-rtmp/
│       ├── nginx-rtmp.conf        # Original config
│       └── nginx-enhanced.conf    # Optimized config
├── cmd/
│   └── streamgen/
│       └── main.go                # Go test stream generator
├── scripts/
│   ├── start-enhanced-streaming.sh
│   └── stop-enhanced-streaming.sh
├── tests/
│   └── live-player.spec.js        # Playwright tests
└── playwright.config.js
```

## 🛠️ Quick Start

### Prerequisites
- Go 1.19+
- FFmpeg with libx264
- NGINX with RTMP module
- Node.js (for Playwright tests)

### 1. Start Enhanced Services
```bash
# Start all services with test streams
./scripts/start-enhanced-streaming.sh --with-test-streams

# Or start without test streams
./scripts/start-enhanced-streaming.sh
```

### 2. Access the Enhanced Player
```bash
# Enhanced live player with all features
http://localhost:3000/live-player.html

# Original players (preserved)
http://localhost:3000/index.html
http://localhost:3000/adaptive-live-player.html
```

### 3. Run Tests
```bash
# Install Playwright
npm install @playwright/test

# Install browsers
npx playwright install

# Run tests
npx playwright test
```

### 4. Stop All Services
```bash
./scripts/stop-enhanced-streaming.sh
```

## 🎯 API Endpoints

### Transcoder Service (Port 8083)
- `GET /health` - Health check
- `GET /qualities` - Get quality profiles
- `POST /transcode/start/{streamKey}` - Start transcoding
- `POST /transcode/stop/{streamKey}` - Stop transcoding
- `GET /transcode/status/{streamKey}` - Get transcoder status
- `GET /transcode/active` - List active transcoders

### HLS Streaming
- `GET /hls/{streamKey}/master.m3u8` - Master playlist
- `GET /hls/{streamKey}/{quality}/index.m3u8` - Quality-specific playlist
- `GET /hls/{streamKey}/{quality}/segment_XXX.ts` - Video segments

## 🔧 Configuration

### Quality Profiles
The transcoder generates 6 quality levels:

| Quality | Resolution | Video Bitrate | Max Bitrate | Buffer Size |
|---------|------------|---------------|-------------|-------------|
| 1080p   | 1920x1080  | 5130k        | 5640k       | 10260k      |
| 720p    | 1280x720   | 2930k        | 3220k       | 5860k       |
| 480p    | 854x480    | 1830k        | 2010k       | 3660k       |
| 360p    | 640x360    | 1060k        | 1160k       | 2120k       |
| 240p    | 426x240    | 620k         | 680k        | 1240k       |
| 144p    | 256x144    | 400k         | 440k        | 800k        |

### HLS Settings
- **Segment Duration**: 2 seconds (low latency)
- **Playlist Type**: Event (enables DVR)
- **Buffer Management**: Keeps all segments for seeking
- **GOP Size**: 48 frames (2 seconds at 24fps)

## 🧪 Testing

### Manual Testing
1. Start the enhanced services with test streams
2. Open `live-player.html` in multiple browser tabs
3. Add multiple streams to each tab
4. Verify quality switching works
5. Test timeline seeking and DVR functionality

### Automated Testing
```bash
# Run all tests
npx playwright test

# Run specific test suite
npx playwright test tests/live-player.spec.js

# Run with UI
npx playwright test --ui

# Generate test report
npx playwright show-report
```

### Test Coverage
- ✅ Multi-stream loading and management
- ✅ Quality selection functionality
- ✅ Timeline seeking and DVR
- ✅ Performance under concurrent load
- ✅ Buffer stability
- ✅ API endpoint validation

## 🔍 Troubleshooting

### Common Issues

**Streams not loading:**
```bash
# Check transcoder status
curl http://localhost:8083/transcode/active

# Check NGINX RTMP stats
curl http://localhost:8080/stat
```

**Quality switching not working:**
```bash
# Verify quality profiles
curl http://localhost:8083/qualities

# Check HLS master playlist
curl http://localhost:8083/hls/stream1/master.m3u8
```

**Timeline seeking issues:**
- Ensure playlist type is "event" for DVR functionality
- Check that segments are being preserved (not deleted)
- Verify sufficient disk space for segment storage

### Performance Optimization

**For high concurrent load:**
1. Increase worker processes in NGINX config
2. Adjust transcoder buffer sizes
3. Use hardware encoding if available
4. Consider CDN for segment delivery

**For low latency:**
1. Reduce segment duration to 1 second
2. Use tune=zerolatency in transcoder
3. Minimize playlist update intervals
4. Optimize network infrastructure

## 📊 Monitoring

### Built-in Monitoring
- Real-time player statistics
- Transcoder process monitoring
- NGINX RTMP statistics
- System log aggregation

### External Monitoring
```bash
# Check service health
curl http://localhost:8083/health
curl http://localhost:8080/health

# Monitor resource usage
htop
iotop
```

## 🔄 Comparison with Reference

The enhanced player implements all features from the reference implementation at `http://188.245.163.8:3000/index.html`:

- ✅ **Quality Selection**: Functional dropdown with backend switching
- ✅ **Timeline Seeking**: Full DVR functionality with historical content
- ✅ **Multi-stream Support**: Concurrent stream viewing
- ✅ **Buffer Management**: Optimized for minimal buffering
- ✅ **Performance**: Go-based services for better resource utilization

## 🚀 Production Deployment

### Docker Support
```bash
# Build transcoder image
docker build -t streamforge-transcoder ./services/transcoder

# Run with docker-compose
docker-compose up -d
```

### Environment Variables
```bash
export RTMP_URL="rtmp://your-rtmp-server:1935/live"
export OUTPUT_DIR="/var/hls"
export PORT="8083"
```

### Security Considerations
- Implement RTMP authentication
- Use HTTPS for HLS delivery
- Add rate limiting
- Configure firewall rules

## 📝 License

This enhanced version maintains the same license as the original StreamForge project.