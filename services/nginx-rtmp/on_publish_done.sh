#!/bin/bash
# NGINX RTMP on_publish_done callback script

STREAM_NAME="$1"
TRANSCODER_URL="http://188.245.163.8:8083"

# Log the unpublish event
echo "[$(date)] Stream unpublished: $STREAM_NAME" >> /var/log/streamforge/rtmp.log

# Call the transcoder API to stop transcoding
curl -X POST "${TRANSCODER_URL}/api/streams/stop/${STREAM_NAME}" \
  -H "Content-Type: application/json" \
  >> /var/log/streamforge/rtmp.log 2>&1

exit 0