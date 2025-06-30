# Architecture Guide: Building a YouTube-Like ABR Live Streaming Platform

This document provides a comprehensive guide to building a robust, adaptive bitrate (ABR) live streaming platform, similar to what you would find on YouTube or Twitch. The goal is to ingest a single high-quality live stream and transcode it into multiple renditions (e.g., 1080p, 720p, 480p) in real-time, allowing viewers to seamlessly switch between qualities based on their network conditions.

---

## 1. High-Level Architecture

The architecture can be broken down into five main components:

1.  **Broadcaster (OBS):** The source of the live stream.
2.  **Ingest Server (NGINX-RTMP):** Receives the high-quality stream.
3.  **Transcoding Engine (FFmpeg):** Creates the multi-quality renditions.
4.  **Packaging & Delivery (HLS):** Formats the streams for delivery.
5.  **Video Player (HTML5):** Plays the stream and handles quality switching.

Here is a visual representation of the workflow:

```
+-------------+
|             |   (1. Single High-Quality RTMP Stream)
|   OBS /     | ---------------------------------------> +----------------------+
| Broadcaster |                                          |                      |
|             |                                          |   NGINX-RTMP Server  |
+-------------+                                          | (Ingest & Packaging) |
                                                         |                      |
                                                         +-------+--------------+
                                                                 |
                                           (2. Execute Transcoding Script)
                                                                 |
                                                                 v
                                                         +-------+--------------+
                                                         |                      |
                                                         |   FFmpeg Transcoder  |
                                                         | (Creates ABR Renditions) |
                                                         |                      |
                                                         +-------+--------------+
                                                                 |
                                             (3. HLS Output: Master Playlist & Segments)
                                                                 |
                                                                 v
+----------------------+
|                      |   (4. HTTP Request for Playlist)
|   Video Player       | <---------------------------------------+----------------------+
| (e.g., Video.js)     |                                         |                      |
|                      |   (5. HTTP Delivery of Segments)          |   Web Server / CDN   |
+----------------------+ ---------------------------------------> | (HLS Delivery)       |
                                                                 |                      |
                                                                 +----------------------+
```

---

## 2. Core Components Explained

### a. Broadcaster (OBS)

*   **Role:** This is the source of your content. Software like OBS (Open Broadcaster Software) captures your video and audio, encodes it into a single, high-quality RTMP stream, and sends it to your ingest server.
*   **Key Configuration:** You should configure OBS to send a stream with a high resolution (e.g., 1080p or 720p) and a stable bitrate. This will be the source for all your lower-quality renditions.

### b. Ingest Server (NGINX-RTMP)

*   **Role:** This is the heart of your streaming server. It listens for incoming RTMP streams from the broadcaster. When a new stream arrives, it triggers the transcoding process.
*   **Key Directive: `exec`**: This powerful directive in the NGINX-RTMP module allows you to execute an external script (like our `transcode.sh` script) for each new stream. This is what automates the transcoding workflow.

### c. Transcoding Engine (FFmpeg)

*   **Role:** FFmpeg is the workhorse that does the heavy lifting. It takes the single high-quality stream from NGINX and transcodes it into multiple, lower-quality streams in real-time. This is a CPU-intensive process.
*   **Critical for ABR:** To ensure smooth quality switching without buffering, FFmpeg must be configured to produce **keyframe-aligned** segments of a **consistent duration** across all renditions.

### d. Packaging & Delivery (HLS)

*   **Role:** HLS (HTTP Live Streaming) is the protocol used to deliver the video to the player. FFmpeg packages the transcoded streams into HLS format, which consists of two main parts:
    *   **`.m3u8` Playlists:** These are text files that list the available video segments.
    *   **`.ts` Segments:** These are short chunks of the video (e.g., 2-4 seconds long).
*   **Master Playlist:** For ABR, FFmpeg creates a **master playlist** that contains references to the individual playlists for each quality. The player downloads this master playlist first to see all the available quality options.

### e. Video Player (HTML5)

*   **Role:** A modern HTML5 video player (like Video.js, HLS.js, or Shaka Player) is responsible for the user experience.
*   **ABR Logic:** The player downloads the master playlist, detects the user's bandwidth, and automatically requests the appropriate quality segments. If the user's network conditions change, the player will seamlessly switch to a higher or lower quality stream.

---

## 3. Step-by-Step Implementation Guide

### Step 1: Configure NGINX-RTMP

Your `nginx-enhanced.conf` should be modified to use the `exec` directive. This configuration is designed for ABR streaming.

**File:** `services/nginx-rtmp/nginx-enhanced.conf`

```nginx
worker_processes auto;
rtmp_auto_push on;

events { worker_connections 4096; }

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            allow publish all;
            allow play all;
            record off;

            # CRITICAL: Execute the transcoding script for each new stream.
            # The `$name` variable is the stream key from OBS (e.g., "my-stream").
            exec /usr/local/bin/transcode.sh $name;

            # HLS settings
            hls on;
            hls_path /tmp/hls; # This is where the HLS files will be stored.
            hls_fragment 2s; # 2-second segments.
            hls_playlist_length 20s; # Keep 20 seconds of video in the playlist.
            hls_continuous on;
            hls_cleanup on;
            hls_fragment_naming system;
            hls_fragment_slicing aligned;
            
            # IMPORTANT: Enable nested playlists for ABR.
            hls_nested on;
        }
    }
}

http {
    sendfile on;
    tcp_nopush on;
    server {
        listen 8080;

        # HLS Delivery Location
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /tmp;
            add_header Cache-Control no-cache;
            add_header 'Access-Control-Allow-Origin' '*' always;
        }
    }
}
```

### Step 2: Create the Transcoding Script

This script is executed by NGINX. It uses a single `ffmpeg` command to create three renditions (720p, 480p, 360p) from the source stream.

**File:** `/usr/local/bin/transcode.sh` (or in your project at `scripts/transcode.sh`)

```bash
#!/bin/bash

# The stream name (e.g., "my-stream") is passed as the first argument from NGINX.
STREAM_NAME=$1
RTMP_URL=rtmp://localhost:1935/live/$STREAM_NAME

# The directory where the HLS files will be stored.
HLS_DIR=/tmp/hls/$STREAM_NAME

mkdir -p $HLS_DIR

# --- FFmpeg Command for ABR Transcoding ---

# This single command reads the input stream once and outputs three renditions.
# This is highly efficient and ensures perfect keyframe alignment.

ffmpeg -i $RTMP_URL \
    -hide_banner -y -v quiet \
    -c:a aac -b:a 128k -ac 2 -ar 44100 \
    -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 \
    -c:v:0 libx264 -preset veryfast -tune zerolatency -g 48 -keyint_min 48 -sc_threshold 0 -filter:v:0 "scale=w=1280:h=720:force_original_aspect_ratio=decrease" -b:v:0 2800k -maxrate:v:0 2996k -bufsize:v:0 4200k \
    -c:v:1 libx264 -preset veryfast -tune zerolatency -g 48 -keyint_min 48 -sc_threshold 0 -filter:v:1 "scale=w=854:h=480:force_original_aspect_ratio=decrease"  -b:v:1 1400k -maxrate:v:1 1498k -bufsize:v:1 2100k \
    -c:v:2 libx264 -preset veryfast -tune zerolatency -g 48 -keyint_min 48 -sc_threshold 0 -filter:v:2 "scale=w=640:h=360:force_original_aspect_ratio=decrease"  -b:v:2 800k  -maxrate:v:2 856k  -bufsize:v:2 1200k \
    -f hls -hls_time 2 -hls_list_size 10 -hls_flags delete_segments \
    -master_pl_name master.m3u8 \
    -hls_segment_filename "$HLS_DIR/%v/segment%03d.ts" \
    -var_stream_map "v:0,a:0,name:720p v:1,a:0,name:480p v:2,a:0,name:360p" $HLS_DIR/%v/playlist.m3u8
```

**Make the script executable:**

```bash
chmod +x /usr/local/bin/transcode.sh
```

### Step 3: How to Use

1.  **Start NGINX:** Make sure your NGINX server is running with the new configuration.
2.  **Start Streaming from OBS:**
    *   Go to `Settings > Stream`.
    *   Set `Service` to `Custom...`.
    *   Set `Server` to `rtmp://<your-server-ip>:1935/live`.
    *   Set `Stream Key` to something unique, like `my-stream`.
    *   Start streaming.
3.  **Play the Stream:**
    *   Open your `live-player.html` or any HLS player.
    *   The URL for the master playlist will be: `http://<your-server-ip>:8080/hls/my-stream/master.m3u8`.

---

## 4. Key Concepts for Smooth ABR (No Buffering!)

*   **Keyframe Alignment:** A keyframe is a full video frame. All other frames in a segment are just the differences from the keyframe. When a player switches quality, it **must** start the new segment on a keyframe. If the keyframes are not aligned across all renditions, the player will have to wait for the next keyframe, causing a buffer.
    *   **How we achieve this:** The `-g 48 -keyint_min 48 -sc_threshold 0` options in our `ffmpeg` command force a keyframe every 48 frames and disable scene detection, ensuring all renditions have keyframes at the exact same moments.

*   **Consistent Segment Duration:** All `.ts` segments across all qualities must have the same duration. If they don't, the player's timeline will get out of sync, leading to buffering or playback errors.
    *   **How we achieve this:** The `-hls_time 2` option in `ffmpeg` ensures every segment is exactly 2 seconds long.

*   **GOP (Group of Pictures):** This is the distance between keyframes. A fixed GOP size is essential for ABR. Our `-g 48` setting creates a GOP of 48 frames.

By following this architecture and these principles, you will have a professional-grade live streaming platform with smooth, YouTube-like adaptive bitrate streaming.
