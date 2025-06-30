# StreamForge: Critical FFmpeg Issues Discovered & Fixed

## Executive Summary

During the development of StreamForge's adaptive HLS streaming platform, we encountered and resolved several critical FFmpeg issues when transitioning from NGINX's built-in HLS to a custom **Go Transcoder + FFmpeg** processing pipeline. This document details the issues, root causes, and solutions implemented.

## Architecture Context

### Original Setup (Problematic)
- **NGINX-RTMP**: RTMP ingestion + built-in HLS generation
- **Issues**: Limited quality control, single bitrate, poor segment handling

### Final Solution (Working)
- **NGINX-RTMP**: RTMP ingestion only
- **Go Transcoder**: Custom FFmpeg orchestration
- **FFmpeg**: Multi-quality HLS generation with proper segment control

## Critical Issues Discovered & Fixed

### 1. FFmpeg Scale Filter Syntax Error

**Issue**: Scale filter syntax causing transcoding failures
```bash
# BROKEN - Invalid syntax
-vf "scale=1920:1080,scale=1280:720,scale=854:480,scale=640:360"
```

**Root Cause**: Multiple scale filters in single `-vf` parameter
**Impact**: Complete transcoding failure, no HLS output

**Solution**: Implemented filter_complex with proper stream mapping
```bash
-filter_complex "[0:v]split=4[v1][v2][v3][v4]; \
[v1]scale=1920:1080[v1080]; \
[v2]scale=1280:720[v720]; \
[v3]scale=854:480[v480]; \
[v4]scale=640:360[v360]"
```

### 2. Unsupported RTMP Options in FFmpeg

**Issue**: FFmpeg failing with unknown RTMP options
```bash
# BROKEN - Invalid FFmpeg options
-rtmp_timeout 5 -reconnect 1
```

**Root Cause**: These are NGINX-RTMP specific options, not FFmpeg options
**Impact**: FFmpeg process termination, stream interruption

**Solution**: Removed unsupported options, implemented proper error handling
```go
// Removed from FFmpeg command generation
// rtmp_timeout and reconnect are NGINX-RTMP directives, not FFmpeg options
```

### 3. HLS Segment Generation Race Conditions

**Issue**: Multiple transcoding processes creating conflicting segments
**Root Cause**: No process locking mechanism
**Impact**: Corrupted playlists, missing segments, playback failures

**Solution**: Implemented atomic file-based locking system
```go
func (m *Manager) acquireStreamLock(streamKey string) error {
    lockFile := filepath.Join(m.lockDir, fmt.Sprintf("%s.lock", streamKey))
    // Atomic file operations to prevent TOCTOU race conditions
    file, err := os.OpenFile(tempLockFile, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
    // ... lock validation and cleanup
}
```

### 4. Invalid Codec Specifications

**Issue**: Incorrect codec parameters causing playback incompatibility
```bash
# BROKEN - Generic codec specs
-c:v libx264 -c:a aac
```

**Root Cause**: Missing H.264 profiles and levels for different quality tiers
**Impact**: Poor compression, compatibility issues, failed playback

**Solution**: Quality-specific codec optimization
```bash
# 1080p - High Profile
-c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p

# 720p - Main Profile  
-c:v libx264 -profile:v main -level 3.1 -pix_fmt yuv420p

# 480p/360p - Baseline Profile
-c:v libx264 -profile:v baseline -level 3.0 -pix_fmt yuv420p
```

### 5. Master Playlist Generation Failures

**Issue**: Malformed master playlist with incorrect CODECS attribute
**Root Cause**: Static codec strings not matching actual encoding
**Impact**: HLS.js unable to properly detect available qualities

**Solution**: Dynamic master playlist generation with proper CODECS
```go
func (h *HLSManager) GenerateMasterPlaylist(streamKey string) error {
    content := "#EXTM3U\n#EXT-X-VERSION:6\n"
    content += fmt.Sprintf("#EXT-X-STREAM-INF:BANDWIDTH=%s,RESOLUTION=%s,CODECS=\"%s\"\n", 
        quality.Bandwidth, quality.Resolution, quality.Codecs)
    // ...
}
```

### 6. Segment Duration Inconsistencies

**Issue**: Variable segment durations causing playback stuttering
**Root Cause**: Inconsistent `-hls_time` parameter application
**Impact**: Poor user experience, buffer underruns

**Solution**: Enforced consistent 4-second segments across all qualities
```bash
-hls_time 4 -hls_list_size 0 -hls_segment_type mpegts
```

### 7. Process Monitoring and Cleanup Issues

**Issue**: Orphaned FFmpeg processes consuming system resources
**Root Cause**: Inadequate process lifecycle management
**Impact**: Memory leaks, system instability

**Solution**: Comprehensive process monitoring with cleanup
```go
func (m *Manager) monitorProcess(streamKey string, hlsManager *HLSManager) {
    defer func() {
        m.mutex.Lock()
        if process, exists := m.processes[streamKey]; exists && process.Status != "stopped" {
            process.Status = "failed"
        }
        m.releaseStreamLock(streamKey)
        m.mutex.Unlock()
    }()
    // ... health checking and cleanup
}
```

## Performance Optimizations Implemented

### 1. FFmpeg Hardware Acceleration
```bash
# Added hardware encoding where available
-hwaccel auto -hwaccel_output_format auto
```

### 2. Buffer Management
```bash
# Optimized buffer sizes for low latency
-bufsize 2800k -maxrate 3000k
```

### 3. Container-Level Optimizations
```yaml
# Docker resource limits
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
```

## Monitoring and Debugging Enhancements

### 1. Comprehensive Logging
- FFmpeg process PID tracking
- Segment generation timestamps
- Error categorization (network, media, fatal)

### 2. Health Check Implementation
```go
func (h *HLSManager) MonitorHLSHealth(streamKey string) (*HLSStats, error) {
    // Check segment freshness, playlist validity, file system health
}
```

### 3. Real-time Status Reporting
- Active transcoder tracking
- Stream quality metrics
- Resource utilization monitoring

## Results Achieved

### Before (NGINX HLS)
- ❌ Single quality output only
- ❌ Limited codec control
- ❌ Poor error handling
- ❌ No process isolation

### After (Go Transcoder + FFmpeg)
- ✅ 4 quality levels (1080p, 720p, 480p, 360p)
- ✅ Optimized codec profiles per quality
- ✅ Robust error handling and recovery
- ✅ Process isolation and monitoring
- ✅ Manual quality selection in player
- ✅ Race condition prevention
- ✅ Resource cleanup and management

## Key Lessons Learned

1. **FFmpeg Option Validation**: Always verify FFmpeg-specific vs application-specific options
2. **Process Isolation**: Implement proper locking mechanisms for concurrent operations
3. **Codec Optimization**: Quality-specific encoding parameters significantly improve output
4. **Monitoring is Critical**: Real-time health checks prevent cascading failures
5. **Cleanup is Essential**: Proper resource management prevents system degradation

## Technical Specifications

### Working FFmpeg Command Template
```bash
ffmpeg -i rtmp://nginx-rtmp:1935/live/stream1 \
  -filter_complex "[0:v]split=4[v1][v2][v3][v4]; \
    [v1]scale=1920:1080[v1080]; \
    [v2]scale=1280:720[v720]; \
    [v3]scale=854:480[v480]; \
    [v4]scale=640:360[v360]" \
  -map "[v1080]" -map 0:a -c:v libx264 -profile:v high -level 4.0 \
    -b:v 5000k -maxrate 5640k -bufsize 5000k -c:a aac -b:a 128k \
    -hls_time 4 -hls_list_size 0 -hls_segment_type mpegts \
    /tmp/hls_shared/stream1/1080p/playlist.m3u8 \
  -map "[v720]" -map 0:a -c:v libx264 -profile:v main -level 3.1 \
    -b:v 2800k -maxrate 3220k -bufsize 2800k -c:a aac -b:a 128k \
    -hls_time 4 -hls_list_size 0 -hls_segment_type mpegts \
    /tmp/hls_shared/stream1/720p/playlist.m3u8 \
  # ... additional quality levels
```

## Conclusion

The transition from NGINX's built-in HLS to a custom Go Transcoder + FFmpeg solution resolved critical streaming issues and enabled advanced features like multi-quality adaptive streaming. The key was understanding FFmpeg's specific requirements and implementing proper process management, error handling, and resource cleanup.

This architecture now supports enterprise-grade live streaming with manual quality control, robust error recovery, and efficient resource utilization.

---

**Document Version**: 1.0  
**Last Updated**: June 30, 2025  
**Project**: StreamForge v2.0  
**Architecture**: NGINX-RTMP + Go Transcoder + FFmpeg HLS