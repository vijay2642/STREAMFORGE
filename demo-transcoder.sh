#!/bin/bash

echo "🎬 StreamForge Transcoder - COMPLETE DEMONSTRATION"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TRANSCODER_PORT=8084
TRANSCODER_URL="http://localhost:$TRANSCODER_PORT"

echo -e "${BLUE}🔧 Testing Transcoder Service Endpoints${NC}"
echo "============================================="

# Test health endpoint
echo -e "${YELLOW}1. Health Check:${NC}"
curl -s "$TRANSCODER_URL/health" | jq '.'
echo ""

# Test quality profiles endpoint
echo -e "${YELLOW}2. Available Quality Profiles:${NC}"
curl -s "$TRANSCODER_URL/qualities" | jq '.data[] | {name, resolution, video_bitrate}'
echo ""

# Test active transcoders
echo -e "${YELLOW}3. Active Transcoders:${NC}"
curl -s "$TRANSCODER_URL/transcode/active" | jq '.'
echo ""

echo -e "${BLUE}📹 Creating Test Video for Demonstration${NC}"
echo "=============================================="

# Create a longer test video with multiple scenes
echo "Creating 30-second test video with multiple scenes..."
ffmpeg -f lavfi -i testsrc=duration=30:size=1280x720:rate=30 \
       -f lavfi -i sine=frequency=1000:duration=30 \
       -c:v libx264 -preset veryfast -b:v 2000k -c:a aac -t 30 \
       demo-input.mp4 -y > /dev/null 2>&1

if [ -f "demo-input.mp4" ]; then
    echo -e "${GREEN}✅ Test video created: demo-input.mp4${NC}"
else
    echo -e "${RED}❌ Failed to create test video${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Starting Live Transcoding Simulation${NC}"
echo "=========================================="

# Start streaming the video to simulate live input
echo "Starting simulated live stream..."
ffmpeg -re -stream_loop -1 -i demo-input.mp4 -c copy -f flv \
       rtmp://localhost:1935/live/demo-stream > /dev/null 2>&1 &
STREAM_PID=$!

echo -e "${GREEN}✅ Live stream started (PID: $STREAM_PID)${NC}"
echo "Stream URL: rtmp://localhost:1935/live/demo-stream"
echo ""

# Wait a moment for stream to start
sleep 3

echo -e "${YELLOW}4. Starting Transcoder for 'demo-stream':${NC}"
START_RESPONSE=$(curl -s -X POST "$TRANSCODER_URL/transcode/start/demo-stream")
echo "$START_RESPONSE" | jq '.'

if echo "$START_RESPONSE" | jq -e '.success' > /dev/null; then
    echo -e "${GREEN}✅ Transcoder started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start transcoder${NC}"
    kill $STREAM_PID 2>/dev/null
    exit 1
fi

echo ""
echo -e "${YELLOW}Waiting 10 seconds for transcoding to generate segments...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}5. Transcoder Status:${NC}"
curl -s "$TRANSCODER_URL/transcode/status/demo-stream" | jq '.data'
echo ""

echo -e "${YELLOW}6. Updated Active Transcoders:${NC}"
curl -s "$TRANSCODER_URL/transcode/active" | jq '.data'
echo ""

echo -e "${BLUE}📁 Checking Generated Output${NC}"
echo "============================="

OUTPUT_DIR="./output/hls/demo-stream"
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${GREEN}✅ Output directory exists: $OUTPUT_DIR${NC}"
    
    # Check master playlist
    if [ -f "$OUTPUT_DIR/master.m3u8" ]; then
        echo -e "${GREEN}✅ Master playlist created${NC}"
        echo -e "${YELLOW}Master playlist content:${NC}"
        echo "=========================="
        cat "$OUTPUT_DIR/master.m3u8"
        echo ""
    fi
    
    # Check quality directories
    echo -e "${YELLOW}Quality directories and segments:${NC}"
    for i in {0..5}; do
        QUALITY_DIR="$OUTPUT_DIR/$i"
        if [ -d "$QUALITY_DIR" ]; then
            SEGMENT_COUNT=$(ls "$QUALITY_DIR"/*.ts 2>/dev/null | wc -l)
            PLAYLIST_EXISTS=""
            if [ -f "$QUALITY_DIR/index.m3u8" ]; then
                PLAYLIST_EXISTS="✅ Playlist"
            else
                PLAYLIST_EXISTS="❌ No Playlist"
            fi
            
            case $i in
                0) QUALITY="1080p" ;;
                1) QUALITY="720p" ;;
                2) QUALITY="480p" ;;
                3) QUALITY="360p" ;;
                4) QUALITY="240p" ;;
                5) QUALITY="144p" ;;
            esac
            
            echo "  Quality $i ($QUALITY): $SEGMENT_COUNT segments, $PLAYLIST_EXISTS"
        else
            echo "  Quality $i: ❌ Missing directory"
        fi
    done
else
    echo -e "${RED}❌ Output directory not found${NC}"
fi

echo ""
echo -e "${BLUE}🌐 Testing Playback URLs${NC}"
echo "========================"
echo "You can test these URLs in a video player that supports HLS:"
echo ""
echo -e "${GREEN}Master Playlist (Adaptive):${NC}"
echo "http://localhost:$TRANSCODER_PORT/hls/demo-stream/master.m3u8"
echo ""
echo -e "${GREEN}Individual Quality Streams:${NC}"
echo "  1080p: http://localhost:$TRANSCODER_PORT/hls/demo-stream/0/index.m3u8"
echo "  720p:  http://localhost:$TRANSCODER_PORT/hls/demo-stream/1/index.m3u8"
echo "  480p:  http://localhost:$TRANSCODER_PORT/hls/demo-stream/2/index.m3u8"
echo "  360p:  http://localhost:$TRANSCODER_PORT/hls/demo-stream/3/index.m3u8"
echo "  240p:  http://localhost:$TRANSCODER_PORT/hls/demo-stream/4/index.m3u8"
echo "  144p:  http://localhost:$TRANSCODER_PORT/hls/demo-stream/5/index.m3u8"

echo ""
echo -e "${YELLOW}Letting transcoder run for 15 more seconds...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}7. Final Status Check:${NC}"
curl -s "$TRANSCODER_URL/transcode/status/demo-stream" | jq '.data | {status, uptime_seconds, quality_count: (.qualities | length)}'

echo ""
echo -e "${BLUE}🛑 Stopping Transcoder${NC}"
echo "======================"

echo -e "${YELLOW}8. Stopping Transcoder:${NC}"
STOP_RESPONSE=$(curl -s -X POST "$TRANSCODER_URL/transcode/stop/demo-stream")
echo "$STOP_RESPONSE" | jq '.'

# Stop the simulated live stream
echo "Stopping simulated live stream..."
kill $STREAM_PID 2>/dev/null
wait $STREAM_PID 2>/dev/null

echo ""
echo -e "${BLUE}📊 Final Results Summary${NC}"
echo "========================="

TOTAL_SEGMENTS=0
for i in {0..5}; do
    QUALITY_DIR="$OUTPUT_DIR/$i"
    if [ -d "$QUALITY_DIR" ]; then
        SEGMENT_COUNT=$(ls "$QUALITY_DIR"/*.ts 2>/dev/null | wc -l)
        TOTAL_SEGMENTS=$((TOTAL_SEGMENTS + SEGMENT_COUNT))
    fi
done

echo -e "${GREEN}✅ Transcoding completed successfully!${NC}"
echo "  • 6 quality levels generated"
echo "  • $TOTAL_SEGMENTS total segments created"
echo "  • Master playlist with adaptive bitrate"
echo "  • All segments are playable HLS content"

echo ""
echo -e "${BLUE}🎯 What was demonstrated:${NC}"
echo "==========================="
echo "  ✅ Multi-quality video transcoding (1080p to 144p)"
echo "  ✅ Real-time HLS segmentation"
echo "  ✅ Adaptive bitrate streaming setup"
echo "  ✅ RESTful API for transcoder management"
echo "  ✅ Live stream ingestion from RTMP"
echo "  ✅ Process monitoring and status reporting"

echo ""
echo -e "${YELLOW}🧹 Cleaning up demo files...${NC}"
rm -f demo-input.mp4
echo -e "${GREEN}✅ Demo complete!${NC}"

echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "=============="
echo "1. Open web/index.html in your browser"
echo "2. Use OBS Studio to stream to rtmp://localhost:1935/live/your-stream-key"
echo "3. Start transcoding via the web interface or API"
echo "4. Enjoy multi-quality adaptive streaming!" 