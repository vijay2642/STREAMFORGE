# StreamForge Transcoder - Quick Start Guide

## 🎬 Multi-Quality Video Transcoding for Live Streams

StreamForge includes a powerful transcoder service that automatically converts incoming RTMP streams into multiple quality levels for adaptive streaming.

### Quality Levels Supported
- **1080p** (1920x1080) - 4.5 Mbps
- **720p** (1280x720) - 2.5 Mbps  
- **480p** (854x480) - 1.5 Mbps
- **360p** (640x360) - 800 Kbps
- **240p** (426x240) - 400 Kbps
- **144p** (256x144) - 200 Kbps

## Quick Start (RTMP + Transcoding)

### 1. Start the RTMP Stack
```bash
make rtmp-up
```

### 2. Start Transcoding for Your Stream
```bash
make start-transcoder STREAM=stream1
```

### 3. Stream from OBS Studio
- **Server**: `rtmp://localhost:1935/live`
- **Stream Key**: `stream1`

### 4. View Your Adaptive Stream
- **Web Player**: Open `web/index.html` in browser
- **Direct HLS**: `http://localhost:8083/hls/stream1/master.m3u8`

## API Usage

The transcoder service provides a REST API on port 8083:

### Start Transcoding
```bash
curl -X POST http://localhost:8083/transcode/start/stream1
```

### Stop Transcoding  
```bash
curl -X POST http://localhost:8083/transcode/stop/stream1
```

### Get Status
```bash
curl http://localhost:8083/transcode/status/stream1
```

### List Active Transcoders
```bash
curl http://localhost:8083/transcode/active
```

## Output Structure

For stream key `stream1`, the transcoder creates:

```
output/hls/stream1/
├── master.m3u8          # Adaptive bitrate playlist
├── 0/                   # 1080p quality
│   ├── index.m3u8
│   └── seg_000.ts, seg_001.ts...
├── 1/                   # 720p quality
│   ├── index.m3u8  
│   └── seg_000.ts, seg_001.ts...
├── 2/                   # 480p quality
├── 3/                   # 360p quality
├── 4/                   # 240p quality
└── 5/                   # 144p quality
```

## Web Player Features

The included web player (`web/index.html`) supports:

- **Adaptive Quality**: Automatically adjusts based on bandwidth
- **Manual Quality Selection**: Choose specific quality levels
- **Real-time Controls**: Start/stop transcoding from the browser
- **Status Monitoring**: View active transcoders and their status

## FFmpeg Command Generated

The transcoder generates optimized FFmpeg commands like:

```bash
ffmpeg -y -i rtmp://localhost:1935/live/stream1 \
  # Multiple quality mappings with proper encoding settings
  -f hls -hls_time 4 -hls_playlist_type event \
  -hls_flags independent_segments \
  -master_pl_name master.m3u8 \
  output/hls/stream1/%v/index.m3u8
```

## Testing

Test the transcoding pipeline:

```bash
# Run the comprehensive test
./test-transcoder.sh

# Manual test with sample video
ffmpeg -re -i sample.mp4 -c copy -f flv rtmp://localhost:1935/live/test
```

## Architecture

```
OBS/Streamer → RTMP Server → Transcoder Service → HLS Output → Web Player
             (nginx-rtmp)   (Go + FFmpeg)      (Multi-quality)  (HLS.js)
```

## Performance Notes

- Uses `libx264` with `veryfast` preset for real-time performance
- 4-second segments for low latency
- Independent segments for better seeking
- Rate control with proper buffer sizes
- Audio passthrough to reduce CPU usage

## Troubleshooting

### Common Issues

1. **FFmpeg not found**: Install FFmpeg with H.264 support
2. **Permission denied**: Ensure output directory is writable
3. **Port conflicts**: Check that ports 1935 and 8083 are available
4. **CORS issues**: Serve web player from a local HTTP server

### Debug Commands

```bash
# Check transcoder health
curl http://localhost:8083/health

# View logs
docker-compose -f docker-compose-rtmp.yml logs -f

# Test FFmpeg directly
./test-transcoder.sh
```

## Next Steps

- Stream from OBS using the RTMP endpoint
- Open the web player to view your multi-quality stream
- Use the API to integrate with your own applications
- Customize quality profiles in `services/transcoder/internal/transcoder/manager.go` 