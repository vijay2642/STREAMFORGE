#!/bin/bash

# StreamForge Enhanced Adaptive Bitrate Transcoding Script
# Optimized for buffer-free streaming with comprehensive error handling
# Fixed version addressing all issues from O3_communication.md

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Logging setup
LOG_DIR="/var/log/streamforge"
LOG_FILE="$LOG_DIR/transcode.log"
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# The stream name is passed as the first argument from NGINX
STREAM_NAME="${1:-}"

if [ -z "$STREAM_NAME" ]; then
    log "ERROR: Stream name not provided"
    exit 1
fi

log "INFO: Starting transcoding for stream: $STREAM_NAME"

# Configuration
RTMP_URL="rtmp://localhost:1935/live/$STREAM_NAME"
HLS_DIR="/tmp/hls_shared/$STREAM_NAME"

# Create output directories
mkdir -p "$HLS_DIR"/{720p,480p,360p}
log "INFO: Created HLS directories for $STREAM_NAME"

# Cleanup function for graceful shutdown
cleanup() {
    log "INFO: Cleaning up transcoding for $STREAM_NAME"
    # Kill any remaining FFmpeg processes for this stream
    pkill -f "transcode.*$STREAM_NAME" || true
}
trap cleanup EXIT

# Enhanced FFmpeg command with FIXED settings for GOP alignment and low latency
log "INFO: Starting FFmpeg transcoding with GOP-aligned, codec-optimized settings"

ffmpeg -y -i "$RTMP_URL" \
    -hide_banner -loglevel info \
    -fflags +genpts -avoid_negative_ts make_zero \
    -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 \
    \
    -c:v:0 libx264 -preset veryfast -tune zerolatency \
    -profile:v:0 main -level:v:0 3.1 \
    -g 60 -keyint_min 60 -sc_threshold 0 -force_key_frames "expr:gte(t,n_forced*2)" \
    -filter:v:0 "scale=w=1280:h=720:force_original_aspect_ratio=decrease:force_divisible_by=2" \
    -b:v:0 2800k -maxrate:v:0 2996k -bufsize:v:0 2800k \
    -c:a:0 aac -b:a:0 128k -ac 2 -ar 44100 \
    \
    -c:v:1 libx264 -preset veryfast -tune zerolatency \
    -profile:v:1 main -level:v:1 3.1 \
    -g 60 -keyint_min 60 -sc_threshold 0 -force_key_frames "expr:gte(t,n_forced*2)" \
    -filter:v:1 "scale=w=854:h=480:force_original_aspect_ratio=decrease:force_divisible_by=2" \
    -b:v:1 1400k -maxrate:v:1 1498k -bufsize:v:1 1400k \
    -c:a:1 aac -b:a:1 96k -ac 2 -ar 44100 \
    \
    -c:v:2 libx264 -preset veryfast -tune zerolatency \
    -profile:v:2 baseline -level:v:2 3.0 \
    -g 60 -keyint_min 60 -sc_threshold 0 -force_key_frames "expr:gte(t,n_forced*2)" \
    -filter:v:2 "scale=w=640:h=360:force_original_aspect_ratio=decrease:force_divisible_by=2" \
    -b:v:2 800k -maxrate:v:2 856k -bufsize:v:2 800k \
    -c:a:2 aac -b:a:2 64k -ac 2 -ar 44100 \
    \
    -f hls -hls_time 2 -hls_list_size 6 \
    -hls_flags delete_segments+independent_segments+program_date_time \
    -hls_start_number_source epoch \
    -hls_segment_type mpegts \
    -master_pl_name master.m3u8 \
    -hls_segment_filename "$HLS_DIR/%v/segment%03d.ts" \
    -var_stream_map "v:0,a:0,name:720p v:1,a:1,name:480p v:2,a:2,name:360p" \
    "$HLS_DIR/%v/playlist.m3u8" 2>&1 | tee -a "$LOG_FILE" || {
        log "ERROR: FFmpeg transcoding failed for $STREAM_NAME"
        exit 1
    }

log "INFO: Transcoding completed for $STREAM_NAME"