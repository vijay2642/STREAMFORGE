#!/bin/bash
# Health check script for StreamForge NGINX-RTMP

# Check if NGINX is running
if ! pgrep nginx > /dev/null; then
    echo "NGINX not running"
    exit 1
fi

# Check if RTMP port is listening
if ! netstat -ln | grep -q ":1935 "; then
    echo "RTMP port 1935 not listening"
    exit 1
fi

# Check if HTTP port is listening
if ! netstat -ln | grep -q ":8080 "; then
    echo "HTTP port 8080 not listening"
    exit 1
fi

echo "All services healthy"
exit 0
