#!/bin/bash
# Enhanced NGINX RTMP on_publish_done callback script with stream lifecycle management
# NGINX passes: name, tcurl, addr, flashver, swfurl, pageurl, clientid

set -euo pipefail

STREAM_NAME="$1"
CLIENT_ADDR="${2:-unknown}"
TRANSCODER_URL="http://transcoder:8083"
HLS_BASE_DIR="/tmp/hls_shared"
LOG_FILE="/var/log/streamforge/rtmp.log"

# Configuration
CLEANUP_ENABLED="${CLEANUP_ENABLED:-true}"
RETENTION_HOURS="${RETENTION_HOURS:-24}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Validate stream name
if [ -z "$STREAM_NAME" ]; then
    log "ERROR: Stream name is empty"
    exit 1
fi

# Sanitize stream name
STREAM_NAME=$(echo "$STREAM_NAME" | sed 's/[^a-zA-Z0-9_-]//g')

if [ -z "$STREAM_NAME" ]; then
    log "ERROR: Stream name is invalid after sanitization"
    exit 1
fi

log "INFO: Stream publish ended - Name: $STREAM_NAME, Client: $CLIENT_ADDR"

# Stop transcoding processes for this stream
log "INFO: Stopping transcoding processes for stream: $STREAM_NAME"
pkill -f "transcode.*$STREAM_NAME" || true

# Notify transcoder service about stream end
log "INFO: Notifying transcoder service about stream end: $STREAM_NAME"
curl -X POST "${TRANSCODER_URL}/transcode/stop/${STREAM_NAME}" \
  --connect-timeout 5 \
  --max-time 10 \
  >> "$LOG_FILE" 2>&1 || {
    log "WARNING: Failed to notify transcoder service, but continuing..."
}

# Stream cleanup based on retention policy
STREAM_DIR="$HLS_BASE_DIR/$STREAM_NAME"

if [ "$CLEANUP_ENABLED" = "true" ] && [ -d "$STREAM_DIR" ]; then
    log "INFO: Applying retention policy for stream: $STREAM_NAME"

    # Mark stream as ended by creating a metadata file
    cat > "$STREAM_DIR/.stream_ended" << EOF
{
    "stream_name": "$STREAM_NAME",
    "ended_at": "$(date -Iseconds)",
    "client_addr": "$CLIENT_ADDR",
    "retention_hours": $RETENTION_HOURS
}
EOF

    # Schedule cleanup based on retention policy
    if [ "$RETENTION_HOURS" -eq 0 ]; then
        log "INFO: Immediate cleanup enabled, removing stream directory: $STREAM_NAME"
        rm -rf "$STREAM_DIR"
    else
        log "INFO: Stream will be cleaned up after $RETENTION_HOURS hours"
        # The cleanup will be handled by a separate cleanup service/cron job
    fi
else
    log "INFO: Cleanup disabled or stream directory not found"
fi

# Update master playlist to indicate stream ended
if [ -d "$STREAM_DIR" ]; then
    cat > "$STREAM_DIR/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-ENDLIST
# Stream ended at $(date -Iseconds)
EOF
fi

log "INFO: Stream cleanup completed for: $STREAM_NAME"
exit 0