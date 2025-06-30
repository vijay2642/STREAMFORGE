# Multi-stage Dockerfile for StreamForge Stream Manager
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
    -o stream-manager \
    .

# Final runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add \
    ca-certificates \
    curl \
    tzdata \
    && update-ca-certificates

# Create non-root user for security
RUN addgroup -g 1001 -S streamforge && \
    adduser -u 1001 -S streamforge -G streamforge

# Create necessary directories
RUN mkdir -p /tmp/hls_shared /app/logs && \
    chown -R streamforge:streamforge /tmp/hls_shared /app/logs

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/stream-manager .
RUN chmod +x stream-manager

# Switch to non-root user
USER streamforge

# Expose port
EXPOSE 8081

# Set environment variables
ENV PORT=8081 \
    TRANSCODER_URL=http://transcoder:8083 \
    NGINX_URL=http://nginx-rtmp:8080 \
    GIN_MODE=release

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8081/health || exit 1

# Run the application
CMD ["./stream-manager"]
