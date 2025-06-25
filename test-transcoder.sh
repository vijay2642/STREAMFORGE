#!/bin/bash

echo "🎬 StreamForge Transcoder - COMPREHENSIVE TEST"
echo "==============================================="

# Create a test video file
echo "📹 Creating test video file..."
ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:duration=10 \
       -c:v libx264 -preset veryfast -b:v 1000k -c:a aac -t 10 test-input.mp4 -y

echo "✅ Test video created: test-input.mp4"

# Test the transcoding command that our service would run
echo ""
echo "🔧 Testing FFmpeg multi-quality transcoding command..."
mkdir -p test-output/{0,1,2,3,4,5}

# This is the exact command our transcoder service generates
ffmpeg -y -i test-input.mp4 \
  -map 0:v -map 0:a -c:v:0 libx264 -s:v:0 1920x1080 -preset veryfast -b:v:0 4500k -maxrate:v:0 5000k -bufsize:v:0 6750k -g 50 -sc_threshold 0 -c:a:0 copy \
  -map 0:v -map 0:a -c:v:1 libx264 -s:v:1 1280x720 -preset veryfast -b:v:1 2500k -maxrate:v:1 2750k -bufsize:v:1 3750k -g 50 -sc_threshold 0 -c:a:1 copy \
  -map 0:v -map 0:a -c:v:2 libx264 -s:v:2 854x480 -preset veryfast -b:v:2 1500k -maxrate:v:2 1600k -bufsize:v:2 2250k -g 50 -sc_threshold 0 -c:a:2 copy \
  -map 0:v -map 0:a -c:v:3 libx264 -s:v:3 640x360 -preset veryfast -b:v:3 800k -maxrate:v:3 856k -bufsize:v:3 1200k -g 50 -sc_threshold 0 -c:a:3 copy \
  -map 0:v -map 0:a -c:v:4 libx264 -s:v:4 426x240 -preset veryfast -b:v:4 400k -maxrate:v:4 450k -bufsize:v:4 600k -g 50 -sc_threshold 0 -c:a:4 copy \
  -map 0:v -map 0:a -c:v:5 libx264 -s:v:5 256x144 -preset veryfast -b:v:5 200k -maxrate:v:5 250k -bufsize:v:5 300k -g 50 -sc_threshold 0 -c:a:5 copy \
  -f hls -hls_time 4 -hls_playlist_type event -hls_flags independent_segments \
  -hls_segment_filename test-output/%v/seg_%03d.ts \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0 v:1,a:1 v:2,a:2 v:3,a:3 v:4,a:4 v:5,a:5" \
  test-output/%v/index.m3u8

echo ""
echo "📊 RESULTS:"
echo "==========="

if [ -f "test-output/master.m3u8" ]; then
    echo "✅ Master playlist created: test-output/master.m3u8"
    echo "📋 Master playlist content:"
    cat test-output/master.m3u8
    echo ""
else
    echo "❌ Master playlist NOT created"
fi

echo "📁 Quality directories created:"
for i in {0..5}; do
    if [ -d "test-output/$i" ]; then
        files=$(ls test-output/$i/ | wc -l)
        echo "  ✅ Quality $i: $files files"
        if [ -f "test-output/$i/index.m3u8" ]; then
            echo "     📋 Playlist exists"
        fi
    else
        echo "  ❌ Quality $i: Missing"
    fi
done

echo ""
echo "🎯 TESTING COMPLETE!"
echo "===================="

if [ -f "test-output/master.m3u8" ]; then
    echo "✅ Multi-quality transcoding WORKS!"
    echo "📺 You can play this with:"
    echo "   - VLC: Open test-output/master.m3u8"
    echo "   - Browser: Use HLS.js player"
    echo ""
    echo "🎨 Quality levels available:"
    echo "   - test-output/0/index.m3u8 (1080p)"
    echo "   - test-output/1/index.m3u8 (720p)"
    echo "   - test-output/2/index.m3u8 (480p)"
    echo "   - test-output/3/index.m3u8 (360p)"
    echo "   - test-output/4/index.m3u8 (240p)"
    echo "   - test-output/5/index.m3u8 (144p)"
else
    echo "❌ Transcoding failed - check FFmpeg installation"
fi

echo ""
echo "🧹 Cleaning up test files..."
rm -f test-input.mp4
rm -rf test-output/
echo "✅ Cleanup complete" 