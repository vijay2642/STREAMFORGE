#!/bin/bash
# Container-based RTMP Stream Monitor
# Runs inside the NGINX-RTMP container to monitor and prepare streams

set -euo pipefail

# Configuration
NGINX_STATS_URL="http://localhost:8080/stat"
HLS_BASE_DIR="/tmp/hls_shared"
LOG_FILE="/var/log/streamforge/stream-monitor.log"
MONITOR_INTERVAL=3

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR: $1" | tee -a "$LOG_FILE"
}

# Function to extract active publishing streams from NGINX stats
get_publishing_streams() {
    local stats_xml
    stats_xml=$(curl -s "$NGINX_STATS_URL" 2>/dev/null || echo "")

    if [[ -z "$stats_xml" ]]; then
        return 1
    fi

    # Extract streams that have <publishing/> tag using a more reliable method
    # First, extract all stream blocks, then filter for those with publishing tag
    echo "$stats_xml" | awk '
    /<stream>/ { in_stream=1; stream_block="" }
    in_stream { stream_block = stream_block $0 "\n" }
    /<\/stream>/ {
        if (stream_block ~ /<publishing\/>/) {
            match(stream_block, /<n>([^<]+)<\/n>/, arr)
            if (arr[1] != "") print arr[1]
        }
        in_stream=0
    }' | sort -u
}

# Function to prepare clean HLS directory
prepare_hls_directory() {
    local stream_name="$1"
    local stream_dir="$HLS_BASE_DIR/$stream_name"
    
    log "Preparing HLS directory for stream: $stream_name"
    
    # Remove existing directory completely
    if [[ -d "$stream_dir" ]]; then
        log "Cleaning existing directory: $stream_dir"
        rm -rf "$stream_dir"
    fi
    
    # Create fresh directory structure
    mkdir -p "$stream_dir"/{720p,480p,360p}
    
    # Set proper permissions
    chmod 755 "$stream_dir"
    chmod 755 "$stream_dir"/{720p,480p,360p}
    
    # Create master playlist
    cat > "$stream_dir/master.m3u8" << 'EOF'
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=2996000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1498000,RESOLUTION=854x480,CODECS="avc1.64001f,mp4a.40.2"
480p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=856000,RESOLUTION=640x360,CODECS="avc1.64001f,mp4a.40.2"
360p/playlist.m3u8
EOF
    
    chmod 644 "$stream_dir/master.m3u8"
    
    log "HLS directory prepared successfully: $stream_dir"
}

# Function to start transcoding
start_transcoding() {
    local stream_name="$1"
    
    log "Starting transcoding for stream: $stream_name"
    
    # Check if already running
    if pgrep -f "transcode.*$stream_name" > /dev/null 2>&1; then
        log "Transcoding already running for: $stream_name"
        return 0
    fi
    
    # Start transcoding in background
    if [[ -f "/usr/local/bin/transcode.sh" ]]; then
        nohup /usr/local/bin/transcode.sh "$stream_name" > "/var/log/streamforge/transcode-$stream_name.log" 2>&1 &
        log "Transcoding started for: $stream_name (PID: $!)"
    else
        log "ERROR: Transcoding script not found: /usr/local/bin/transcode.sh"
    fi
}

# Function to monitor HLS generation
monitor_hls_generation() {
    local stream_name="$1"
    local stream_dir="$HLS_BASE_DIR/$stream_name"
    local check_count=0
    local max_checks=15
    
    log "Monitoring HLS generation for: $stream_name"
    
    while [[ $check_count -lt $max_checks ]]; do
        sleep 2
        check_count=$((check_count + 1))
        
        # Check for .ts segments
        if find "$stream_dir" -name "*.ts" -type f 2>/dev/null | head -1 | grep -q .; then
            log "SUCCESS: HLS segments detected for: $stream_name"
            return 0
        fi
        
        # Check for .m3u8 playlists
        if find "$stream_dir" -name "playlist.m3u8" -type f 2>/dev/null | head -1 | grep -q .; then
            log "INFO: Playlists detected for: $stream_name"
        fi
    done
    
    log "WARNING: No HLS segments after ${max_checks} checks for: $stream_name"
    return 1
}

# Main monitoring function
monitor_streams() {
    log "Starting RTMP stream monitor (interval: ${MONITOR_INTERVAL}s)"
    
    declare -A processed_streams
    
    while true; do
        # Get currently publishing streams
        publishing_streams=$(get_publishing_streams 2>/dev/null || echo "")
        
        if [[ -n "$publishing_streams" ]]; then
            while IFS= read -r stream_name; do
                [[ -z "$stream_name" ]] && continue
                
                # Process new streams
                if [[ -z "${processed_streams[$stream_name]:-}" ]]; then
                    log "NEW STREAM DETECTED: $stream_name"
                    
                    # Immediate directory preparation
                    prepare_hls_directory "$stream_name"
                    
                    # Start transcoding
                    start_transcoding "$stream_name"
                    
                    # Mark as processed
                    processed_streams["$stream_name"]=1
                    
                    # Monitor HLS generation in background
                    (monitor_hls_generation "$stream_name") &
                fi
            done <<< "$publishing_streams"
        fi
        
        # Clean up streams that are no longer publishing
        for stream_name in "${!processed_streams[@]}"; do
            if ! echo "$publishing_streams" | grep -q "^$stream_name$"; then
                log "STREAM ENDED: $stream_name"
                
                # Stop transcoding processes
                pkill -f "transcode.*$stream_name" 2>/dev/null || true
                
                # Remove from processed list
                unset processed_streams["$stream_name"]
            fi
        done
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Handle signals
trap 'log "Stream monitor shutting down"; exit 0' SIGTERM SIGINT

# Start monitoring
log "Initializing RTMP stream monitor"
monitor_streams
