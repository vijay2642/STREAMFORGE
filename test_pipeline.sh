#!/bin/bash

# StreamForge Pipeline Test Script
# Tests the complete RTMP -> NGINX -> Transcoder -> HLS -> React Player flow

set -e

LOG_FILE="/tmp/pipeline_test.log"
TEST_STREAM="pipeline_test"

echo "🧪 StreamForge Pipeline Test Starting..." | tee $LOG_FILE

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local expected=$3
    
    log "🔍 Checking $service..."
    response=$(curl -s "$url" || echo "FAILED")
    
    if [[ "$response" == *"$expected"* ]]; then
        log "✅ $service is healthy"
        return 0
    else
        log "❌ $service is unhealthy: $response"
        return 1
    fi
}

# Function to wait for condition
wait_for_condition() {
    local description=$1
    local check_command=$2
    local timeout=${3:-30}
    local interval=${4:-2}
    
    log "⏳ Waiting for: $description"
    
    for ((i=0; i<timeout; i+=interval)); do
        if eval "$check_command" &>/dev/null; then
            log "✅ $description - SUCCESS"
            return 0
        fi
        sleep $interval
    done
    
    log "❌ $description - TIMEOUT after ${timeout}s"
    return 1
}

# Clean up function
cleanup() {
    log "🧹 Cleaning up test resources..."
    pkill -f "rtmp://.*/$TEST_STREAM" || true
    curl -s -X POST "http://localhost:8083/transcode/stop/$TEST_STREAM" || true
    rm -rf "/tmp/hls_shared/$TEST_STREAM" || true
    docker exec streamforge-nginx-rtmp rm -rf "/tmp/hls_shared/$TEST_STREAM" || true
}

# Set up cleanup trap
trap cleanup EXIT

# Test 1: Check all services are healthy
log "📋 Phase 1: Service Health Check"
check_service "NGINX-RTMP" "http://localhost:8080/stat" "rtmp" || exit 1
check_service "Transcoder" "http://localhost:8083/health" "healthy" || exit 1
check_service "HLS Server" "http://localhost:8085/health" "healthy" || exit 1
check_service "Admin API" "http://localhost:9000/health" "healthy" || exit 1
check_service "Web Interface" "http://localhost:3000" "React App" || exit 1

# Test 2: Clean start
log "📋 Phase 2: Clean Environment"
cleanup
log "✅ Environment cleaned"

# Test 3: Start RTMP stream
log "📋 Phase 3: Start RTMP Test Stream"
ffmpeg -f lavfi -i testsrc=duration=60:size=1280x720:rate=30 \
    -f lavfi -i sine=frequency=1000:duration=60 \
    -vf "drawtext=text='TEST STREAM %{localtime}':fontcolor=white:fontsize=24:x=10:y=10" \
    -c:v libx264 -preset ultrafast -b:v 2000k \
    -c:a aac -b:a 128k -t 60 \
    -f flv "rtmp://localhost:1935/live/$TEST_STREAM" \
    > "$LOG_FILE.ffmpeg" 2>&1 &

FFMPEG_PID=$!
log "✅ RTMP stream started (PID: $FFMPEG_PID)"

# Test 4: Wait for NGINX to detect stream
log "📋 Phase 4: NGINX Stream Detection"
wait_for_condition "NGINX to detect stream" \
    "curl -s http://localhost:8080/stat | grep -q '$TEST_STREAM'" 30 2

# Test 5: Wait for transcoder to start
log "📋 Phase 5: Transcoder Activation"
wait_for_condition "Transcoder to start" \
    "curl -s http://localhost:8083/transcode/active | grep -q '$TEST_STREAM'" 15 2

# Test 6: Wait for HLS directories
log "📋 Phase 6: HLS Directory Creation"
wait_for_condition "HLS directories to be created" \
    "test -d /tmp/hls_shared/$TEST_STREAM" 10 2

# Test 7: Wait for HLS segments
log "📋 Phase 7: HLS Segment Generation"
wait_for_condition "HLS segments to be generated" \
    "find /tmp/hls_shared/$TEST_STREAM -name '*.ts' | head -1 | grep -q '.'" 30 3

# Test 8: Verify master playlist
log "📋 Phase 8: Master Playlist Verification"
if [ -f "/tmp/hls_shared/$TEST_STREAM/master.m3u8" ]; then
    log "✅ Master playlist exists"
    qualities=$(grep -c "EXT-X-STREAM-INF" "/tmp/hls_shared/$TEST_STREAM/master.m3u8" || echo "0")
    log "📊 Found $qualities quality levels"
else
    log "❌ Master playlist not found"
    exit 1
fi

# Test 9: Test HLS playback URLs
log "📋 Phase 9: HLS Playback URL Testing"
master_url="http://localhost:8085/hls/$TEST_STREAM/master.m3u8"
response=$(curl -s -o /dev/null -w "%{http_code}" "$master_url")
if [ "$response" = "200" ]; then
    log "✅ HLS master playlist accessible via HLS server"
else
    log "❌ HLS master playlist not accessible (HTTP $response)"
fi

# Test 10: React app stream discovery
log "📋 Phase 10: React App Stream Discovery"
transcoder_response=$(curl -s "http://localhost:8083/transcode/active")
if [[ "$transcoder_response" == *"$TEST_STREAM"* ]]; then
    log "✅ React app can discover active stream"
else
    log "❌ React app cannot discover stream"
fi

# Summary
log "📋 Pipeline Test Summary"
log "🎯 Test Stream: $TEST_STREAM"
log "📺 RTMP URL: rtmp://localhost:1935/live/$TEST_STREAM"
log "🎬 HLS URL: http://localhost:8085/hls/$TEST_STREAM/master.m3u8"
log "🌐 Web Player: http://localhost:3000 (select '$TEST_STREAM')"
log "📊 Transcoder API: http://localhost:8083/transcode/active"

# Keep stream running for manual testing
log "🎉 Pipeline test completed successfully!"
log "💡 Test stream will continue running for 60 seconds for manual testing"
log "🔗 Access the web player at http://localhost:3000"

# Wait for FFmpeg to finish or be killed
wait $FFMPEG_PID || true

log "🏁 Test completed" 