#!/bin/bash
# Proactive RTMP Stream Monitoring and Directory Management System
# Monitors RTMP connections and prepares HLS directories immediately

set -euo pipefail

# Configuration
NGINX_STATS_URL="http://localhost:8080/stat"
HLS_BASE_DIR="/tmp/hls_shared"
LOG_FILE="/var/log/streamforge/stream-monitor.log"
MONITOR_INTERVAL=2
TRANSCODER_URL="http://localhost:8083"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if a stream is actively publishing
check_active_streams() {
    local stats_xml
    stats_xml=$(curl -s "$NGINX_STATS_URL" 2>/dev/null || echo "")
    
    if [[ -z "$stats_xml" ]]; then
        return 1
    fi
    
    # Extract stream names that are actively publishing
    echo "$stats_xml" | grep -o '<n>[^<]*</n>' | sed 's/<n>//g; s/<\/n>//g' | grep -v '^$'
}

# Function to clean and prepare HLS directory for a stream
prepare_stream_directory() {
    local stream_name="$1"
    local stream_dir="$HLS_BASE_DIR/$stream_name"
    
    log "INFO: Preparing directory for stream: $stream_name"
    
    # Remove existing directory if it exists
    if [[ -d "$stream_dir" ]]; then
        log "INFO: Cleaning existing directory: $stream_dir"
        rm -rf "$stream_dir"
    fi
    
    # Create fresh directory structure
    mkdir -p "$stream_dir"/{720p,480p,360p}
    
    # Set proper permissions
    chmod 755 "$stream_dir"
    chmod 755 "$stream_dir"/{720p,480p,360p}
    
    # Create master playlist template
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
    
    # Set permissions on master playlist
    chmod 644 "$stream_dir/master.m3u8"
    
    log "INFO: Directory structure created successfully for stream: $stream_name"
}

# Function to start transcoding for a stream
start_transcoding() {
    local stream_name="$1"
    
    log "INFO: Starting transcoding for stream: $stream_name"
    
    # Check if transcoding is already running
    if pgrep -f "transcode.*$stream_name" > /dev/null; then
        log "INFO: Transcoding already running for stream: $stream_name"
        return 0
    fi
    
    # Start transcoding script in background
    nohup /usr/local/bin/transcode.sh "$stream_name" > "/var/log/streamforge/transcode-$stream_name.log" 2>&1 &
    local transcode_pid=$!
    
    log "INFO: Transcoding started for stream: $stream_name (PID: $transcode_pid)"
    
    # Notify transcoder service
    if command -v curl > /dev/null; then
        curl -s -X POST "$TRANSCODER_URL/api/stream/start" \
            -H "Content-Type: application/json" \
            -d "{\"stream_name\":\"$stream_name\"}" > /dev/null 2>&1 || true
    fi
}

# Function to stop transcoding for a stream
stop_transcoding() {
    local stream_name="$1"
    
    log "INFO: Stopping transcoding for stream: $stream_name"
    
    # Kill transcoding processes for this stream
    pkill -f "transcode.*$stream_name" || true
    
    # Notify transcoder service
    if command -v curl > /dev/null; then
        curl -s -X POST "$TRANSCODER_URL/api/stream/stop" \
            -H "Content-Type: application/json" \
            -d "{\"stream_name\":\"$stream_name\"}" > /dev/null 2>&1 || true
    fi
    
    log "INFO: Transcoding stopped for stream: $stream_name"
}

# Function to verify HLS segment generation
verify_hls_generation() {
    local stream_name="$1"
    local stream_dir="$HLS_BASE_DIR/$stream_name"
    local timeout=30
    local elapsed=0
    
    log "INFO: Verifying HLS generation for stream: $stream_name"
    
    while [[ $elapsed -lt $timeout ]]; do
        # Check if any .ts segments exist
        if find "$stream_dir" -name "*.ts" -type f | head -1 | grep -q .; then
            log "INFO: HLS segments detected for stream: $stream_name"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log "WARNING: No HLS segments generated for stream: $stream_name after ${timeout}s"
    return 1
}

# Main monitoring loop
main() {
    log "INFO: Starting proactive RTMP stream monitor"
    log "INFO: Monitoring interval: ${MONITOR_INTERVAL}s"
    log "INFO: HLS base directory: $HLS_BASE_DIR"
    
    declare -A known_streams
    
    while true; do
        # Get currently active streams
        active_streams=$(check_active_streams)
        
        if [[ -n "$active_streams" ]]; then
            while IFS= read -r stream_name; do
                # Skip empty lines
                [[ -z "$stream_name" ]] && continue
                
                # Check if this is a new stream
                if [[ -z "${known_streams[$stream_name]:-}" ]]; then
                    log "INFO: New stream detected: $stream_name"
                    
                    # Prepare directory immediately
                    prepare_stream_directory "$stream_name"
                    
                    # Start transcoding
                    start_transcoding "$stream_name"
                    
                    # Mark as known
                    known_streams["$stream_name"]=1
                    
                    # Verify HLS generation in background
                    (
                        sleep 5
                        verify_hls_generation "$stream_name"
                    ) &
                fi
            done <<< "$active_streams"
        fi
        
        # Check for streams that are no longer active
        for stream_name in "${!known_streams[@]}"; do
            if ! echo "$active_streams" | grep -q "^$stream_name$"; then
                log "INFO: Stream no longer active: $stream_name"
                stop_transcoding "$stream_name"
                unset known_streams["$stream_name"]
            fi
        done
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Handle signals
trap 'log "INFO: Stream monitor shutting down"; exit 0' SIGTERM SIGINT

# Start monitoring
main "$@"
