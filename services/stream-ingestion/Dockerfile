# Build stage
FROM golang:1.21-alpine AS builder

# Install FFmpeg for RTMP processing
RUN apk add --no-cache ffmpeg

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./services/stream-ingestion

# Final stage
FROM alpine:latest

# Install FFmpeg and ca-certificates
RUN apk --no-cache add ca-certificates ffmpeg

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Create directories for streams
RUN mkdir -p /tmp/streams

# Expose ports
EXPOSE 8081 1935

# Run the binary
CMD ["./main"] 