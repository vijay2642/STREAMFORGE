#!/bin/bash
# StreamForge permissions initialization script
# This script ensures all directories have proper permissions

echo "🔧 Initializing StreamForge permissions..."

# Create base directories if they don't exist
mkdir -p /tmp/streamforge/hls
mkdir -p /tmp/streamforge/recordings
mkdir -p ./logs

# Set permissions to allow all containers to write
chmod -R 777 /tmp/streamforge
chmod -R 777 ./logs

echo "✅ Permissions initialized successfully"