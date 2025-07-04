# Multi-stage Dockerfile for StreamForge Transcoder Service
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    gcc \
    musl-dev

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a -installsuffix cgo \
    -ldflags='-w -s -extldflags "-static"' \
    -o transcoder \
    .

# Final runtime stage
FROM alpine:latest

# Install runtime dependencies including ffmpeg
RUN apk --no-cache add \
    ca-certificates \
    curl \
    tzdata \
    ffmpeg \
    && update-ca-certificates

# Create necessary directories with full permissions
RUN mkdir -p /tmp/hls_shared /app/logs && \
    chmod -R 777 /tmp/hls_shared /app/logs

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/transcoder .
RUN chmod +x transcoder

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Run as root for full permissions
# USER root

# Expose port
EXPOSE 8083

# Set environment variables
ENV PORT=8083 \
    RTMP_URL=rtmp://nginx-rtmp:1935/live \
    OUTPUT_DIR=/tmp/hls_shared \
    GIN_MODE=release

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8083/health || exit 1

# Run the application
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD []