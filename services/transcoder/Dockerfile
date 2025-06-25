# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the transcoder service
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o transcoder ./services/transcoder

# Final stage
FROM alpine:latest

# Install FFmpeg and other dependencies
RUN apk --no-cache add \
    ffmpeg \
    ca-certificates \
    tzdata

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/transcoder .

# Create output directory for HLS files
RUN mkdir -p /app/output/hls

# Expose port
EXPOSE 8083

# Run the transcoder service
CMD ["./transcoder", "-output-dir", "/app/output/hls"] 