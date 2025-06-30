#!/bin/bash
# StreamForge stop script

echo "🛑 Stopping StreamForge..."

# Stop auto-transcode monitor
if [ -f ./logs/auto-transcode.pid ]; then
    PID=$(cat ./logs/auto-transcode.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "Stopping auto-transcode monitor (PID: $PID)..."
        kill $PID
        rm -f ./logs/auto-transcode.pid
    fi
fi

# Stop Docker containers
echo "Stopping Docker containers..."
docker-compose down

echo "✅ StreamForge stopped"