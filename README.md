# StreamForge - Live Streaming Platform

A comprehensive Go-based microservices architecture for a live streaming platform supporting multiple concurrent streams and real-time playback.

## Architecture Overview

StreamForge consists of 8 core microservices:

1. **Stream Ingestion Service** - Handles incoming live video streams (RTMP/WebRTC)
2. **Stream Processing Service** - Transcodes, segments, and prepares streams for distribution
3. **Stream Distribution Service** - Serves video content to viewers (HLS/DASH)
4. **User Management Service** - Handles user authentication, authorization, and profiles
5. **Stream Metadata Service** - Manages stream information, titles, descriptions, viewer counts
6. **API Gateway** - Routes requests and handles load balancing
7. **Notification Service** - Real-time notifications for stream events
8. **Analytics Service** - Tracks viewer metrics and stream performance

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

### Local Development Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd StreamForge
```

2. Start all services:
```bash
docker-compose up -d
```

3. Initialize databases:
```bash
make init-db
```

4. Access the services:
- API Gateway: http://localhost:8080
- Stream Ingestion: rtmp://localhost:1935
- Web Dashboard: http://localhost:3000

## Service Endpoints

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| API Gateway | 8080 | HTTP | Main API entry point |
| Stream Ingestion | 1935 | RTMP | Stream input |
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