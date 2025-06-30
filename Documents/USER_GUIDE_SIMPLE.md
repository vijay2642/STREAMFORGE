# 📺 StreamForge - Simple User Guide
*How to run your own YouTube-like streaming platform - Now FULLY AUTOMATED!*

## 🚀 Super Quick Start (1 minute!)

### ONE Command to Rule Them All!
```bash
cd /root/STREAMFORGE
./start.sh
```

This **ONE** command:
- ✅ Cleans up old data automatically
- ✅ Creates all necessary directories  
- ✅ Sets proper permissions
- ✅ Builds and starts all services
- ✅ **Starts auto-transcoding monitor**
- ✅ **No manual setup required!**

**Wait 30 seconds** for everything to start up. ✋

### ✅ Check Everything is Working
Open your web browser and go to:
- **http://localhost:3000** (Your streaming website)
- **http://localhost:8080/stat** (System status - should show XML data)

If both pages load, you're ready! 🎉

---

## 📡 How to Stream (OBS Setup)

### 🎥 OBS Studio (Recommended)
1. **Open OBS Studio** 
2. **Go to Settings > Stream**  
3. **Set these values:**
   - Service: `Custom...`
   - Server: `rtmp://localhost:1935/live`
   - Stream Key: `stream1` (or any name you want)
4. **Click "Start Streaming"**

### 🤖 What Happens AUTOMATICALLY:
1. **Stream Detection** → Auto-monitor detects your stream in 5 seconds
2. **Auto-Transcoding** → Starts creating 720p, 480p, 360p versions
3. **Auto-Directory** → Creates HLS directories with proper permissions
4. **Auto-Serving** → Stream appears on web player immediately

**No manual commands needed!** 🎯

---

## 👀 How to Watch Streams

### Method 1: Web Browser (Easiest)
1. **Open your browser**
2. **Go to**: `http://localhost:3000`
3. **Select your stream** from the dropdown
4. **Click Play** and enjoy! 🍿

### Method 2: Direct HLS Link (For Developers)
```
http://localhost:8085/hls/STREAM_NAME/master.m3u8
```

**⚠️ IMPORTANT**: Use port **8085** for HLS (not 8083)!

### Method 3: VLC Media Player
- **VLC**: Open Network Stream → `http://localhost:8085/hls/stream1/master.m3u8`

---

## 🔧 Managing Your Streams (All Automated!)

### Check What's Happening:
```bash
# Check active streams
curl http://localhost:8083/transcode/active

# Check system status
docker-compose ps

# View auto-transcode logs
tail -f logs/auto-transcode.log
```

### Manual Control (Rarely Needed):
```bash
# Stop a specific stream
curl -X POST http://localhost:8083/transcode/stop/STREAM_NAME

# Check NGINX stats
curl http://localhost:8080/stat
```

---

## 🛑 How to Stop Everything

### Simple Stop:
```bash
./stop.sh
```

This automatically:
- ✅ Stops auto-transcode monitor
- ✅ Stops all Docker containers
- ✅ Preserves your data

### Complete Cleanup:
```bash
./stop.sh
rm -rf /tmp/streamforge/*
rm -rf ./logs/*
```

---

## 🆘 Troubleshooting (Now Much Simpler!)

### "Can't Connect to RTMP"
```bash
# Check if everything is running
docker-compose ps

# Restart if needed
./stop.sh && ./start.sh
```

### "Stream Not Appearing"
```bash
# Check auto-transcode monitor
tail -f logs/auto-transcode.log

# Should show: "Starting transcoder for new stream: YOUR_STREAM"
```

### "Video Won't Play"
1. **Check HLS URL**: Use port **8085** not 8083
2. **Correct format**: `http://localhost:8085/hls/STREAM_NAME/master.m3u8`
3. **Try different browser** (Chrome/Safari work best)

### "Seeing Old/Stale Streams"
```bash
# Nuclear option - fixes 99% of issues
./stop.sh
rm -rf /tmp/streamforge/*
./start.sh
```

---

## 📋 Quick Reference

### Important URLs:
- **🌐 Web Player**: `http://localhost:3000`
- **📊 System Stats**: `http://localhost:8080/stat`  
- **🔧 Transcoder API**: `http://localhost:8083/transcode/active`
- **📺 HLS Streams**: `http://localhost:8085/hls/STREAM_NAME/master.m3u8`

### Essential Commands:
```bash
# Start everything (automated)
./start.sh

# Stop everything
./stop.sh

# Check status
docker-compose ps

# View logs
tail -f logs/auto-transcode.log
```

### OBS Settings:
- **Server**: `rtmp://localhost:1935/live`
- **Stream Key**: Any name (e.g., `stream1`, `gaming`, `live_show`)

---

## 🎯 Complete Workflow Example

```bash
# 1. Start platform (one command!)
./start.sh

# 2. Open OBS and start streaming to: rtmp://localhost:1935/live/my_show
#    → Auto-transcoding starts in 5 seconds!

# 3. Watch at: http://localhost:3000
#    → Your stream appears automatically!

# 4. When done:
./stop.sh
```

**That's it!** Fully automated streaming platform! 🚀

---

## 🎪 Multiple Streams

You can run **unlimited simultaneous streams**:
- **Camera 1**: Stream key `camera1`
- **Screen Share**: Stream key `desktop`  
- **Event**: Stream key `live_event`

Each stream:
- ✅ Auto-detected
- ✅ Auto-transcoded to 3 qualities
- ✅ Auto-served on web player

---

## 🌟 New Automation Features

### Auto-Transcode Monitor
- 🔍 Scans for new streams every 5 seconds
- 🎬 Automatically starts transcoding
- 🛡️ Prevents duplicate transcoders
- 📝 Logs everything to `logs/auto-transcode.log`

### Smart Directory Management  
- 📁 Creates stream directories automatically
- 🔐 Sets proper permissions (777)
- 🧹 Cleans up on restart

### One-Command Operations
- `./start.sh` - Start everything
- `./stop.sh` - Stop everything cleanly
- No Docker knowledge required!

---

## 🔥 Pro Tips

1. **Stream Names**: Use simple names like `stream1`, `gaming`, `live`
2. **Multiple Streams**: Just use different stream keys in OBS
3. **Monitoring**: Watch `tail -f logs/auto-transcode.log` to see what's happening
4. **Performance**: Each stream uses ~1 CPU core for transcoding
5. **Network**: Each viewer uses ~2-3 Mbps bandwidth

---

## 🎉 What's Automated Now?

✅ **Stream Detection** - No manual commands  
✅ **Transcoding Start** - Happens automatically  
✅ **Directory Creation** - Auto-managed  
✅ **Permission Setting** - Never worry about this  
✅ **Service Health** - Auto-monitoring  
✅ **Cleanup** - Smart restart procedures  

**You just stream. We handle the rest!** 🤖

---

*💡 Tip: Bookmark `http://localhost:3000` and share it with viewers!*

*🔒 Security Note: For production, use your server's real IP instead of localhost.*

**Happy Streaming!** 🚀