#!/bin/bash
set -e

# Create necessary directories
mkdir -p /tmp/hls_shared /tmp/recordings /var/log/streamforge

# Set proper permissions
chown -R streamforge:streamforge /tmp/hls_shared /tmp/recordings /var/log/streamforge

# Start nginx in foreground
exec nginx -g "daemon off;"
