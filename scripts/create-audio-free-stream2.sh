#!/bin/bash

# Create an audio-free test stream for stream2
# This will generate a video-only stream with no audio track

echo "🎬 Creating audio-free Stream 2..."

# Kill any existing ffmpeg processes for stream2
pkill -f "stream2"

# Generate a test pattern video with NO audio
ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=30 \
       -f lavfi -i color=c=blue:size=1920x1080:rate=30 \
       -filter_complex "[0:v][1:v]blend=all_mode=overlay:all_opacity=0.3" \
       -vcodec libx264 \
       -preset ultrafast \
       -tune zerolatency \
       -b:v 2500k \
       -maxrate 2500k \
       -bufsize 5000k \
       -g 60 \
       -keyint_min 60 \
       -sc_threshold 0 \
       -an \
       -f flv \
       rtmp://188.245.163.8:1935/live/stream2 &

echo "✅ Audio-free Stream 2 started (PID: $!)"
echo "📺 Stream should be available at: http://188.245.163.8/hls/stream2.m3u8"
echo "🔇 This stream has NO AUDIO - only video"
echo ""
echo "To stop this stream, run: pkill -f stream2"
