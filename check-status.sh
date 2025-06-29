#!/bin/bash

echo "🚀 StreamForge Zero-Buffer Status"
echo "================================="
echo ""

# Check Docker containers
echo "📦 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep streamforge
echo ""

# Check processes
echo "⚙️  Processes:"
ps aux | grep -E "(transcoder|ffmpeg)" | grep -v grep | awk '{print $11, $12, $13}'
echo ""

# Check nginx config
echo "🔧 NGINX Configuration:"
docker exec streamforge_nginx-rtmp_1 grep -n "transcode" /etc/nginx/nginx.conf
echo ""

# Service URLs
IP=$(hostname -I | awk '{print $1}')
echo "🌐 Service URLs:"
echo "   RTMP Ingest: rtmp://$IP:1935/live"
echo "   HLS Output:  http://$IP:8080/hls/<stream-key>/master.m3u8"
echo "   Zero-Buffer Player: http://$IP:8080/zero-buffer-player.html"
echo "   Stats Page:  http://$IP:8080/stat"
echo ""

# Current streams
echo "📡 Active Streams:"
curl -s http://localhost:8080/stat 2>/dev/null | grep -oP '(?<=<name>)[^<]+' | grep -v "live" || echo "   No active streams"
echo ""

echo "✅ System ready for zero-buffer streaming!"