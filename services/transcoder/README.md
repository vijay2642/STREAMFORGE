# StreamForge Transcoder Service

The Transcoder Service provides multi-quality adaptive streaming by converting RTMP streams into HLS format with multiple quality variants. It enables viewers to automatically switch between different resolutions based on their bandwidth, providing optimal viewing experience.

## Features

- **Multi-Quality Transcoding**: Converts RTMP streams to 6 quality levels (1080p, 720p, 480p, 360p, 240p, 144p)
- **Adaptive Streaming**: Generates HLS master playlists for automatic quality switching
- **RESTful API**: HTTP endpoints for managing transcoding processes
- **Real-time Monitoring**: Track active transcoders and their status
- **Containerized**: Docker support with FFmpeg included

## Quality Profiles

| Quality | Resolution | Video Bitrate | Max Bitrate | Buffer Size | Use Case |
|---------|------------|---------------|-------------|-------------|----------|
| 1080p   | 1920x1080  | 4500k        | 5000k       | 6750k       | High-speed internet |
| 720p    | 1280x720   | 2500k        | 2750k       | 3750k       | Standard HD |
| 480p    | 854x480    | 1500k        | 1600k       | 2250k       | Mobile/tablet |
| 360p    | 640x360    | 800k         | 856k        | 1200k       | Low bandwidth |
| 240p    | 426x240    | 400k         | 450k        | 600k        | Very low bandwidth |
| 144p    | 256x144    | 200k         | 250k        | 300k        | Ultra low bandwidth |

## API Endpoints

### Health Check
```http
GET /health
```

### Start Transcoding
```http
POST /transcode/start/{streamKey}
```
Starts transcoding for the specified stream key.

**Response:**
```json
{
  "success": true,
  "message": "Transcoder started successfully",
  "stream_key": "stream1",
  "hls_url": "/hls/stream1/master.m3u8"
}
```

### Stop Transcoding
```http
POST /transcode/stop/{streamKey}
```
Stops transcoding for the specified stream key.

### Get Transcoder Status
```http
GET /transcode/status/{streamKey}
```
Returns the status of a specific transcoder.

**Response:**
```json
{
  "success": true,
  "data": {
    "stream_key": "stream1",
    "status": "running",
    "start_time": "2024-01-15T10:30:00Z",
    "uptime": "5m30s",
    "output_dir": "/app/output/hls/stream1",
    "hls_url": "/hls/stream1/master.m3u8",
    "qualities": [
      {"name": "1080p", "url": "/hls/stream1/0/index.m3u8"},
      {"name": "720p", "url": "/hls/stream1/1/index.m3u8"},
      {"name": "480p", "url": "/hls/stream1/2/index.m3u8"},
      {"name": "360p", "url": "/hls/stream1/3/index.m3u8"},
      {"name": "240p", "url": "/hls/stream1/4/index.m3u8"},
      {"name": "144p", "url": "/hls/stream1/5/index.m3u8"}
    ]
  }
}
```

### Get Active Transcoders
```http
GET /transcode/active
```
Returns all currently active transcoding processes.

## Usage

### 1. Start the RTMP and Transcoder Services
```bash
# Start the complete streaming stack
make rtmp-up
```

### 2. Start Transcoding for a Stream
```bash
# Using the API directly
curl -X POST http://localhost:8083/transcode/start/stream1

# Using make command
make start-transcoder STREAM=stream1
```

### 3. Stream from OBS Studio
- **Server**: `rtmp://localhost:1935/live`
- **Stream Key**: `stream1` (or any key you started transcoding for)

### 4. View the Stream
- **Adaptive HLS**: `http://localhost:8083/hls/stream1/master.m3u8`
- **Specific Quality**: `http://localhost:8083/hls/stream1/0/index.m3u8` (for 1080p)
- **Web Player**: Open `web/index.html` in your browser

### 5. Monitor Transcoding
```bash
# Get status for a specific stream
make transcoder-status STREAM=stream1

# Get all active transcoders
make active-transcoders
```

## Directory Structure

When transcoding is active, the following directory structure is created:

```
output/hls/
└── {streamKey}/
    ├── master.m3u8          # Master playlist for adaptive streaming
    ├── 0/                   # 1080p quality
    │   ├── index.m3u8
    │   ├── seg_000.ts
    │   ├── seg_001.ts
    │   └── ...
    ├── 1/                   # 720p quality
    │   ├── index.m3u8
    │   └── ...
    ├── 2/                   # 480p quality
    ├── 3/                   # 360p quality
    ├── 4/                   # 240p quality
    └── 5/                   # 144p quality
```

## Configuration

The transcoder service accepts the following command-line flags:

- `-port`: HTTP server port (default: 8083)
- `-rtmp-url`: RTMP server URL (default: rtmp://localhost:1935/live)
- `-output-dir`: HLS output directory (default: ./output/hls)

### Environment Variables (Docker)

- `RTMP_URL`: Override the RTMP server URL

## Development

### Running Locally
```bash
# Run the transcoder service locally
make run-transcoder

# Or with custom parameters
go run ./services/transcoder -port 8083 -rtmp-url rtmp://localhost:1935/live
```

### Building
```bash
# Build the transcoder binary
make build-transcoder

# Build Docker image
docker-compose -f docker-compose-rtmp.yml build transcoder
```

## Dependencies

- **FFmpeg**: Required for video transcoding (included in Docker image)
- **Gin**: HTTP framework for API endpoints
- **Go**: Runtime environment

## Troubleshooting

### Common Issues

1. **FFmpeg not found**
   - Ensure FFmpeg is installed on your system
   - For Docker: FFmpeg is included in the container

2. **RTMP stream not found**
   - Verify the RTMP server is running
   - Check that the stream key exists and is publishing

3. **Permission errors**
   - Ensure the output directory is writable
   - Check Docker volume permissions

4. **High CPU usage**
   - Transcoding is CPU-intensive, especially with multiple quality variants
   - Consider reducing quality levels or using hardware acceleration

### Logs

View transcoder logs:
```bash
# Docker logs
docker-compose -f docker-compose-rtmp.yml logs transcoder

# Or specific service logs
make rtmp-logs
```

## Performance Considerations

- Each transcoding session uses significant CPU resources
- Memory usage increases with the number of concurrent transcoders
- Storage space is required for HLS segments (automatically cleaned up by FFmpeg)
- Network bandwidth is needed to pull RTMP streams and serve HLS content

## Future Enhancements

- Hardware acceleration support (NVENC, QuickSync)
- Dynamic quality profiles based on input stream
- Automatic transcoder cleanup for inactive streams
- WebRTC output support
- CDN integration for global distribution 