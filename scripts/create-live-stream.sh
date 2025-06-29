#!/bin/bash

# StreamForge - Create Continuous Live Test Stream
# This creates a truly live stream that runs continuously

set -euo pipefail

STREAM_KEY="${1:-stream1}"
LOG_DIR="/root/STREAMFORGE/logs"
LOG_FILE="$LOG_DIR/live-stream.log"

echo "🎬 Creating continuous live stream for: $STREAM_KEY"

# Kill any existing FFmpeg processes for this stream
pkill -f "rtmp://.*/$STREAM_KEY" || true

# Wait a moment
sleep 2

# Start transcoder service for this stream
echo "📡 Starting transcoder for $STREAM_KEY..."
curl -X POST "http://localhost:8083/api/streams/start/$STREAM_KEY" > /dev/null 2>&1 || echo "Transcoder may already be running"

# Create a dynamic test stream with moving elements and timestamp
echo "🎥 Starting continuous FFmpeg stream..."
ffmpeg -re \
  -f lavfi -i "testsrc2=size=1280x720:rate=30" \
  -f lavfi -i "sine=frequency=1000:sample_rate=44100" \
  -vf "drawtext=text='LIVE STREAM - %{localtime}':fontcolor=white:fontsize=24:x=10:y=10:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -b:v 2000k -maxrate 2200k -bufsize 2000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 128k -ac 2 -ar 44100 \
  -f flv "rtmp://localhost:1935/live/$STREAM_KEY" \
  >> "$LOG_FILE" 2>&1 &

FFMPEG_PID=$!
echo "✅ Live stream started (PID: $FFMPEG_PID)"
echo "📺 Stream key: $STREAM_KEY"
echo "🔗 Watch at: http://localhost:3001 (select $STREAM_KEY)"
echo "📊 Stop with: kill $FFMPEG_PID"

# Save PID for easy stopping
echo $FFMPEG_PID > "$LOG_DIR/live-stream-$STREAM_KEY.pid"

echo "🎉 Continuous live stream is now running!"
echo "   - This stream will run until manually stopped"
echo "   - Shows live timestamp updates"
echo "   - View in React app or VLC player"