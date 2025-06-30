#!/bin/bash
# StreamForge automated startup script

echo "🚀 Starting StreamForge with automated setup..."

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down -v

# Clean up old data
echo "🧹 Cleaning up old data..."
rm -rf /tmp/streamforge/*
rm -rf ./logs/*

# Initialize permissions
echo "🔧 Initializing permissions..."
./scripts/init-permissions.sh

# Rebuild services with new configurations
echo "🔨 Building services..."
docker-compose build

# Start all services
echo "🚀 Starting all services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Check service health
echo "🏥 Checking service health..."
docker-compose ps

echo "✅ StreamForge is ready!"
echo ""
echo "📺 Access points:"
echo "   Web Interface: http://localhost:3000"
echo "   RTMP Server:   rtmp://localhost:1935/live"
echo "   HLS Server:    http://localhost:8085/hls/"
echo "   Admin API:     http://localhost:9000"
echo ""
echo "🎬 To stream:"
echo "   OBS Server: rtmp://localhost:1935/live"
echo "   Stream Key: Any name (e.g., stream1, myshow, etc.)"
echo ""

# Start auto-transcode monitor in background
echo "🔄 Starting auto-transcode monitor..."
nohup ./scripts/auto-transcode.sh > ./logs/auto-transcode.log 2>&1 &
echo $! > ./logs/auto-transcode.pid
echo "✅ Auto-transcode monitor started (PID: $(cat ./logs/auto-transcode.pid))"
echo ""
echo "Transcoding will start automatically when you begin streaming!"