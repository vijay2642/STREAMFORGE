# StreamForge - Live Streaming Platform

A comprehensive Go-based microservices architecture for a live streaming platform supporting multiple concurrent streams and real-time playback.

## Architecture Overview

StreamForge consists of 9 core microservices:

1. **Stream Ingestion Service** - Handles incoming live video streams (RTMP/WebRTC)
2. **Stream Processing Service** - Transcodes, segments, and prepares streams for distribution
3. **Stream Distribution Service** - Serves video content to viewers (HLS/DASH)
4. **Transcoder Service** - Multi-quality adaptive streaming with 6 quality levels (1080p-144p)
5. **User Management Service** - Handles user authentication, authorization, and profiles
6. **Stream Metadata Service** - Manages stream information, titles, descriptions, viewer counts
7. **API Gateway** - Routes requests and handles load balancing
8. **Notification Service** - Real-time notifications for stream events
9. **Analytics Service** - Tracks viewer metrics and stream performance

## Technology Stack

- **Language**: Go 1.21
- **Communication**: gRPC + HTTP/REST
- **Databases**: PostgreSQL, Redis
- **Message Queue**: Redis Streams
- **Containerization**: Docker
- **Orchestration**: Docker Compose
- **API Documentation**: OpenAPI/Swagger

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Go 1.21+ (for development)
- FFmpeg (for stream processing)

### RTMP Streaming Setup (Quickstart)

For immediate RTMP streaming with multi-quality transcoding:

1. Clone the repository:
```bash
git clone <repository-url>
cd StreamForge
```

2. Start RTMP streaming stack:
```bash
make rtmp-up
```

3. Start transcoding for your stream:
```bash
make start-transcoder STREAM=stream1
```

4. Stream from OBS Studio:
- **Server**: `rtmp://localhost:1935/live`
- **Stream Key**: `stream1`

5. View adaptive stream:
- **Web Player**: Open `web/index.html` in browser
- **Direct HLS**: `http://localhost:8083/hls/stream1/master.m3u8`

### Full Development Setup

1. Start all services:
```bash
docker-compose up -d
```

2. Initialize databases:
```bash
make init-db
```

3. Access the services:
- API Gateway: http://localhost:8080
- RTMP Server: rtmp://localhost:1935
- Transcoder API: http://localhost:8083
- Web Player: file://web/index.html

## Service Endpoints

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| API Gateway | 8080 | HTTP | Main API entry point |
| RTMP Server | 1935 | RTMP | Stream input (nginx-rtmp) |
| Transcoder Service | 8083 | HTTP | Multi-quality transcoding |
| Stream Distribution | 8084 | HTTP | HLS/DASH delivery |
| User Management | 8081 | gRPC/HTTP | User operations |
| Stream Metadata | 8082 | gRPC/HTTP | Stream info |
| Notification | 8085 | WebSocket | Real-time events |
| Analytics | 8086 | gRPC/HTTP | Metrics |

## Development

### Running Individual Services

Each service can be run independently:

```bash
cd services/stream-ingestion
go run main.go
```

### Building All Services

```bash
make build-all
```

### Running Tests

```bash
make test-all
```

## Configuration

Services are configured via environment variables. See `config/` directory for examples.

## Documentation

- [API Documentation](./docs/api.md)
- [Architecture Guide](./docs/architecture.md)
- [Deployment Guide](./docs/deployment.md)

## License

MIT License 