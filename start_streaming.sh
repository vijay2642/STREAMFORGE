#!/bin/bash

echo "🎬 Starting StreamForge Multi-Quality Streaming..."

# Check if processes are already running
if pgrep -f "multi_quality_transcoder.py" > /dev/null; then
    echo "⚠️  Transcoders already running. Stopping existing processes..."
    pkill -f "multi_quality_transcoder.py"
    pkill -f "cors_server.py"
    sleep 2
fi

# Start CORS server
echo "🌐 Starting CORS server (port 8085)..."
python3 bin/cors_server.py &

# Start web server  
echo "🖥️  Starting web server (port 3000)..."
cd web && python3 -m http.server 3000 --bind 0.0.0.0 > ../logs/web_server.log 2>&1 &
cd ..

# Start multi-quality transcoders for common streams
echo "🎯 Starting multi-quality transcoders..."
python3 bin/multi_quality_transcoder.py stream1 &
python3 bin/multi_quality_transcoder.py stream3 &

echo ""
echo "✅ StreamForge is now running!"
echo ""
echo "📺 Access your streams:"
echo "   • Adaptive Player: http://$(hostname -I | awk '{print $1}'):3000/adaptive-live-player.html"
echo "   • Stream1 HLS: http://$(hostname -I | awk '{print $1}'):8085/stream1/master.m3u8"
echo "   • Stream3 HLS: http://$(hostname -I | awk '{print $1}'):8085/stream3/master.m3u8"
echo ""
echo "🎮 OBS Settings:"
echo "   • Server: rtmp://$(hostname -I | awk '{print $1}'):1935/live"
echo "   • Stream Key: stream1 or stream3"
echo ""
echo "📊 Monitor with: python3 userinput.py" 