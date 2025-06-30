#!/bin/bash
# Auto-transcode script that monitors RTMP streams and starts transcoding

TRANSCODER_URL="http://localhost:8083"
RTMP_STATS_URL="http://localhost:8080/stat"

echo "🔄 Auto-transcode monitor started..."

while true; do
    # Get list of active RTMP streams
    STREAMS=$(curl -s $RTMP_STATS_URL | grep -oP '(?<=<name>)[^<]+(?=</name>)' | grep -v '^live$' || true)
    
    if [ ! -z "$STREAMS" ]; then
        # Get list of currently transcoding streams
        ACTIVE_TRANSCODERS=$(curl -s $TRANSCODER_URL/transcode/active | jq -r '.data[].stream_key' 2>/dev/null || echo "")
        
        # Check each RTMP stream
        for STREAM in $STREAMS; do
            # Check if this stream is already being transcoded
            if ! echo "$ACTIVE_TRANSCODERS" | grep -q "^$STREAM$"; then
                echo "🎬 Starting transcoder for new stream: $STREAM"
                curl -X POST "$TRANSCODER_URL/transcode/start/$STREAM" 2>/dev/null || true
            fi
        done
    fi
    
    sleep 5
done