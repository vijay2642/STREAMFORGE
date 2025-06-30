# Multi-stage Dockerfile for StreamForge Admin API
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
    -o admin-api \
    .

# Final runtime stage
FROM alpine:latest

# Install runtime dependencies including system monitoring tools
RUN apk --no-cache add \
    ca-certificates \
    curl \
    tzdata \
    procps \
    coreutils \
    && update-ca-certificates

# Create non-root user for security
RUN addgroup -g 1001 -S streamforge && \
    adduser -u 1001 -S streamforge -G streamforge

# Create necessary directories
RUN mkdir -p /tmp/hls_shared /tmp/recordings /app/logs && \
    chown -R streamforge:streamforge /tmp/hls_shared /tmp/recordings /app/logs

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/admin-api .
RUN chmod +x admin-api

# Switch to non-root user
USER streamforge

# Expose port
EXPOSE 9000

# Set environment variables
ENV PORT=9000 \
    GIN_MODE=release

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:9000/health || exit 1

# Run the application
CMD ["./admin-api"]
