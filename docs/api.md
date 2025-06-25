# StreamForge API Documentation

## Overview

StreamForge provides a comprehensive REST API for managing live streaming operations. The API is organized into several microservices, each handling specific aspects of the streaming platform.

## Base URLs

| Service | Port | Base URL |
|---------|------|----------|
| API Gateway | 8080 | `http://localhost:8080/api/v1` |
| Stream Ingestion | 8081 | `http://localhost:8081/api/v1` |
| Stream Processing | 8082 | `http://localhost:8082/api/v1` |
| Stream Distribution | 8083 | `http://localhost:8083/api/v1` |
| User Management | 8084 | `http://localhost:8084/api/v1` |
| Stream Metadata | 8085 | `http://localhost:8085/api/v1` |
| Notification | 8086 | `http://localhost:8086/api/v1` |
| Analytics | 8087 | `http://localhost:8087/api/v1` |

## Authentication

Most endpoints require JWT authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## API Endpoints

### User Management Service

#### Register User
```http
POST /users/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "secure_password",
  "first_name": "John",
  "last_name": "Doe"
}
```

#### Login
```http
POST /users/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "secure_password"
}
```

#### Get User Profile
```http
GET /users/profile
Authorization: Bearer <token>
```

#### Update Profile
```http
PUT /users/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "first_name": "John",
  "last_name": "Smith"
}
```

### Stream Ingestion Service

#### Start Stream
```http
POST /streams/{streamKey}/start
Content-Type: application/json

{
  "title": "My Live Stream",
  "description": "A great live stream"
}
```

#### Stop Stream
```http
POST /streams/{streamKey}/stop
```

#### Get Stream Status
```http
GET /streams/{streamKey}/status
```

#### Get Active Streams
```http
GET /streams/active
```

### Stream Processing Service

#### Process Stream
```http
POST /process/{streamKey}
Content-Type: application/json

{
  "input_url": "rtmp://localhost:1935/live/stream_key",
  "formats": [
    {
      "name": "720p",
      "resolution": "1280x720",
      "bitrate": 2500,
      "codec": "libx264",
      "format": "m3u8"
    }
  ]
}
```

#### Stop Processing
```http
DELETE /process/{streamKey}
```

#### Get Processing Status
```http
GET /process/{streamKey}/status
```

#### Get Supported Formats
```http
GET /formats
```

### Stream Distribution Service

#### Get HLS Playlist
```http
GET /hls/{streamKey}/playlist.m3u8
```

#### Get HLS Segment
```http
GET /hls/{streamKey}/segment_{number}.ts
```

#### Get DASH Manifest
```http
GET /dash/{streamKey}/manifest.mpd
```

### Stream Metadata Service

#### Create Stream
```http
POST /streams
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "My Stream",
  "description": "Stream description",
  "is_private": false
}
```

#### Update Stream
```http
PUT /streams/{streamId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Updated Stream Title",
  "description": "Updated description"
}
```

#### Get Stream
```http
GET /streams/{streamId}
```

#### List Streams
```http
GET /streams?page=1&per_page=10&status=online
```

#### Delete Stream
```http
DELETE /streams/{streamId}
Authorization: Bearer <token>
```

### Notification Service

#### Get Notifications
```http
GET /notifications
Authorization: Bearer <token>
```

#### Mark as Read
```http
PUT /notifications/{notificationId}/read
Authorization: Bearer <token>
```

#### WebSocket Connection
```javascript
// Connect to WebSocket for real-time notifications
const ws = new WebSocket('ws://localhost:8086/ws');
```

### Analytics Service

#### Get Stream Analytics
```http
GET /analytics/streams/{streamId}?from=2023-01-01&to=2023-12-31
Authorization: Bearer <token>
```

#### Get User Analytics
```http
GET /analytics/users/{userId}
Authorization: Bearer <token>
```

#### Get Platform Analytics
```http
GET /analytics/platform
Authorization: Bearer <token>
```

## Response Format

All API responses follow this format:

```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    // Response data here
  },
  "meta": {
    // Pagination metadata (when applicable)
    "page": 1,
    "per_page": 10,
    "total": 100,
    "total_pages": 10
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message description",
  "details": {
    // Additional error details
  }
}
```

## Status Codes

| Code | Meaning |
|------|---------|
| 200 | OK - Request successful |
| 201 | Created - Resource created successfully |
| 400 | Bad Request - Invalid request parameters |
| 401 | Unauthorized - Authentication required |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 409 | Conflict - Resource already exists |
| 422 | Unprocessable Entity - Validation errors |
| 500 | Internal Server Error - Server error |

## Rate Limiting

API requests are rate-limited per user:
- 1000 requests per hour for authenticated users
- 100 requests per hour for anonymous users

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Streaming Protocols

### RTMP Ingestion
- **URL**: `rtmp://localhost:1935/live/{stream_key}`
- **Supported**: H.264 video, AAC audio
- **Recommended**: 1080p@30fps, 2500kbps

### HLS Playback
- **URL**: `http://localhost:8083/hls/{stream_key}/playlist.m3u8`
- **Segment Duration**: 4 seconds
- **Supported Players**: VLC, ExoPlayer, Video.js

### DASH Playback
- **URL**: `http://localhost:8083/dash/{stream_key}/manifest.mpd`
- **Adaptive Bitrate**: Multiple quality levels
- **Supported Players**: DASH.js, ExoPlayer

## WebSocket Events

### Real-time Stream Events
```javascript
// Event types
{
  "type": "stream_started",
  "stream_id": "uuid",
  "data": { /* stream data */ },
  "timestamp": "2023-12-01T12:00:00Z"
}

{
  "type": "viewer_joined",
  "stream_id": "uuid",
  "data": { "viewer_count": 42 },
  "timestamp": "2023-12-01T12:00:00Z"
}

{
  "type": "viewer_count_updated",
  "stream_id": "uuid", 
  "data": { "viewer_count": 43 },
  "timestamp": "2023-12-01T12:00:00Z"
}
```

## Examples

### Starting a Live Stream

1. **Register/Login** to get authentication token
2. **Create stream metadata** via Stream Metadata Service
3. **Configure streaming software** (OBS, FFmpeg) with RTMP URL
4. **Start streaming** to RTMP endpoint
5. **Process stream** via Stream Processing Service
6. **Distribute** via Stream Distribution Service

### Complete Example with cURL

```bash
# 1. Register user
curl -X POST http://localhost:8084/api/v1/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"streamer","email":"streamer@example.com","password":"password123"}'

# 2. Login
TOKEN=$(curl -X POST http://localhost:8084/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"streamer@example.com","password":"password123"}' | jq -r '.data.token')

# 3. Create stream
STREAM_ID=$(curl -X POST http://localhost:8085/api/v1/streams \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"My First Stream","description":"Testing the platform"}' | jq -r '.data.id')

# 4. Start RTMP stream (using FFmpeg)
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=1000 \
  -vcodec libx264 -acodec aac -f flv rtmp://localhost:1935/live/your-stream-key

# 5. Process stream
curl -X POST http://localhost:8082/api/v1/process/your-stream-key \
  -H "Content-Type: application/json" \
  -d '{"input_url":"rtmp://localhost:1935/live/your-stream-key"}'

# 6. Play stream
# Open http://localhost:8083/hls/your-stream-key/playlist.m3u8 in VLC
```

## SDK and Libraries

### JavaScript/TypeScript
```bash
npm install @streamforge/js-sdk
```

### Go
```bash
go get github.com/streamforge/go-sdk
```

### Python
```bash
pip install streamforge-sdk
```

For more detailed examples and SDK documentation, visit our [GitHub repository](https://github.com/streamforge/platform). 