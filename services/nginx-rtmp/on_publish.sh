#!/bin/bash
# NGINX RTMP on_publish callback script
# NGINX passes: name, tcurl, addr, flashver, swfurl, pageurl, clientid

STREAM_NAME="$1"
TRANSCODER_URL="http://188.245.163.8:8083"

# Log the publish event
echo "[$(date)] Stream published: $STREAM_NAME from $3" >> /var/log/streamforge/rtmp.log

# Call the transcoder API to start transcoding
curl -X POST "${TRANSCODER_URL}/api/streams/start/${STREAM_NAME}" \
  -H "Content-Type: application/json" \
  -d "{\"stream_name\":\"${STREAM_NAME}\"}" \
  >> /var/log/streamforge/rtmp.log 2>&1

exit 0