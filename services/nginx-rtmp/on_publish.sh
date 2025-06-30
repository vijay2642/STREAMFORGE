#!/bin/bash
# Enhanced NGINX RTMP on_publish callback script with dynamic stream management
# NGINX passes: name, tcurl, addr, flashver, swfurl, pageurl, clientid

# Removed strict error handling for debugging
# set -euo pipefail

STREAM_NAME="$1"
CLIENT_ADDR="${2:-unknown}"
TRANSCODER_URL="http://transcoder:8083"
HLS_BASE_DIR="/tmp/hls_shared"
LOG_FILE="/var/log/streamforge/rtmp.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Validate stream name
if [ -z "$STREAM_NAME" ]; then
    log "ERROR: Stream name is empty"
    exit 1
fi

# Sanitize stream name (remove potentially dangerous characters)
STREAM_NAME=$(echo "$STREAM_NAME" | sed 's/[^a-zA-Z0-9_-]//g')

if [ -z "$STREAM_NAME" ]; then
    log "ERROR: Stream name is invalid after sanitization"
    exit 1
fi

log "INFO: Stream publish started - Name: $STREAM_NAME, Client: $CLIENT_ADDR"
log "DEBUG: Script called with args: $*"

# Clean up any existing stream directory first to ensure fresh start
STREAM_DIR="$HLS_BASE_DIR/$STREAM_NAME"
if [ -d "$STREAM_DIR" ]; then
    log "INFO: Cleaning existing directory for fresh start: $STREAM_DIR"
    rm -rf "$STREAM_DIR"
fi

log "INFO: Creating standardized directory structure for stream: $STREAM_NAME"

# Create all necessary directories including 1080p following standard structure
mkdir -p "$STREAM_DIR"/{1080p,720p,480p,360p}

# Set proper permissions - make writable by all
chmod -R 777 "$STREAM_DIR"

# Create master playlist template with 1080p support
cat > "$STREAM_DIR/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.64002a,mp4a.40.2"
1080p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2996000,RESOLUTION=1280x720,CODECS="avc1.64001f,mp4a.40.2"
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1498000,RESOLUTION=854x480,CODECS="avc1.64001e,mp4a.40.2"
480p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=856000,RESOLUTION=640x360,CODECS="avc1.64001e,mp4a.40.2"
360p/playlist.m3u8
EOF

log "INFO: Directory structure created successfully for stream: $STREAM_NAME"

# Notify transcoder service about new stream
log "INFO: Notifying transcoder service about new stream: $STREAM_NAME"
curl -X POST "${TRANSCODER_URL}/transcode/start/${STREAM_NAME}" \
  --connect-timeout 5 \
  --max-time 10 \
  >> "$LOG_FILE" 2>&1 || {
    log "WARNING: Failed to notify transcoder service, but continuing..."
}

log "INFO: Stream publish setup completed for: $STREAM_NAME"
exit 0