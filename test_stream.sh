#!/bin/bash

echo "Testing StreamForge Dynamic Stream Detection..."
echo "=============================================="

# Test with a sample video (using color bars)
echo "Starting test stream 'test_stream'..."
ffmpeg -f lavfi -i testsrc=duration=30:size=1280x720:rate=30 \
       -f lavfi -i sine=frequency=1000:duration=30 \
       -c:v libx264 -preset veryfast -b:v 2000k \
       -c:a aac -b:a 128k \
       -f flv rtmp://localhost:1935/live/test_stream \
       -loglevel error &

FFMPEG_PID=$!

sleep 5

echo "Checking if stream is detected..."
curl -s http://localhost:8083/transcode/active | jq

echo "Checking RTMP stats..."
curl -s http://localhost:8080/stat | grep -A5 "test_stream" || echo "Stream not found in RTMP stats"

echo "Waiting for test to complete..."
wait $FFMPEG_PID

echo "Test complete!"