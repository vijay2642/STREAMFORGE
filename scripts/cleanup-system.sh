#!/bin/bash

# Thunderbird Streaming Platform - System Cleanup Script
# Usage: ./cleanup-system.sh [type] [timeframe]
# Types: hls, recordings, logs, all
# Timeframes: hour, day, week, all

set -e

LOG_FILE="/root/STREAMFORGE/logs/cleanup.log"
HLS_DIR="/tmp/hls_shared"
RECORDINGS_DIR="/tmp/recordings"
LOGS_DIR="/root/STREAMFORGE/logs"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Calculate file count and size
get_file_stats() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local file_count=$(find "$dir" -type f | wc -l)
        local total_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "$file_count files, $total_size"
    else
        echo "Directory not found"
    fi
}

# Cleanup HLS segments
cleanup_hls() {
    local timeframe="$1"
    log "Starting HLS cleanup (timeframe: $timeframe)"
    
    local before_stats=$(get_file_stats "$HLS_DIR")
    log "Before cleanup: $before_stats"
    
    case "$timeframe" in
        "hour")
            find "$HLS_DIR" -name "*.ts" -type f -mmin +60 -delete 2>/dev/null || true
            find "$HLS_DIR" -name "*.m3u8" -type f -mmin +60 -delete 2>/dev/null || true
            ;;
        "day")
            find "$HLS_DIR" -name "*.ts" -type f -mtime +1 -delete 2>/dev/null || true
            find "$HLS_DIR" -name "*.m3u8" -type f -mtime +1 -delete 2>/dev/null || true
            ;;
        "week")
            find "$HLS_DIR" -name "*.ts" -type f -mtime +7 -delete 2>/dev/null || true
            find "$HLS_DIR" -name "*.m3u8" -type f -mtime +7 -delete 2>/dev/null || true
            ;;
        "all")
            if [ -d "$HLS_DIR" ]; then
                rm -rf "$HLS_DIR"/*
                # Recreate stream directories with proper permissions
                mkdir -p "$HLS_DIR/stream1" "$HLS_DIR/stream2"
                chown -R nobody:nogroup "$HLS_DIR"
                chmod -R 755 "$HLS_DIR"
            fi
            ;;
        *)
            log "Invalid timeframe for HLS cleanup: $timeframe"
            return 1
            ;;
    esac
    
    local after_stats=$(get_file_stats "$HLS_DIR")
    log "After cleanup: $after_stats"
    log "HLS cleanup completed"
}

# Cleanup recordings
cleanup_recordings() {
    local timeframe="$1"
    log "Starting recordings cleanup (timeframe: $timeframe)"
    
    local before_stats=$(get_file_stats "$RECORDINGS_DIR")
    log "Before cleanup: $before_stats"
    
    case "$timeframe" in
        "hour")
            find "$RECORDINGS_DIR" -name "*.flv" -type f -mmin +60 -delete 2>/dev/null || true
            ;;
        "day")
            find "$RECORDINGS_DIR" -name "*.flv" -type f -mtime +1 -delete 2>/dev/null || true
            ;;
        "week")
            find "$RECORDINGS_DIR" -name "*.flv" -type f -mtime +7 -delete 2>/dev/null || true
            ;;
        "all")
            if [ -d "$RECORDINGS_DIR" ]; then
                rm -rf "$RECORDINGS_DIR"/*
            fi
            ;;
        *)
            log "Invalid timeframe for recordings cleanup: $timeframe"
            return 1
            ;;
    esac
    
    local after_stats=$(get_file_stats "$RECORDINGS_DIR")
    log "After cleanup: $after_stats"
    log "Recordings cleanup completed"
}

# Cleanup logs
cleanup_logs() {
    local timeframe="$1"
    log "Starting logs cleanup (timeframe: $timeframe)"
    
    local before_stats=$(get_file_stats "$LOGS_DIR")
    log "Before cleanup: $before_stats"
    
    case "$timeframe" in
        "hour")
            find "$LOGS_DIR" -name "*.log" -type f -mmin +60 -delete 2>/dev/null || true
            ;;
        "day")
            find "$LOGS_DIR" -name "*.log" -type f -mtime +1 -delete 2>/dev/null || true
            ;;
        "week")
            find "$LOGS_DIR" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
            # Keep cleanup.log
            ;;
        "all")
            if [ -d "$LOGS_DIR" ]; then
                find "$LOGS_DIR" -name "*.log" -type f ! -name "cleanup.log" -delete 2>/dev/null || true
            fi
            ;;
        *)
            log "Invalid timeframe for logs cleanup: $timeframe"
            return 1
            ;;
    esac
    
    local after_stats=$(get_file_stats "$LOGS_DIR")
    log "After cleanup: $after_stats"
    log "Logs cleanup completed"
}

# Get disk usage report
disk_usage_report() {
    log "=== Disk Usage Report ==="
    log "HLS Directory: $(get_file_stats "$HLS_DIR")"
    log "Recordings Directory: $(get_file_stats "$RECORDINGS_DIR")"
    log "Logs Directory: $(get_file_stats "$LOGS_DIR")"
    
    log "Detailed HLS breakdown:"
    if [ -d "$HLS_DIR" ]; then
        for stream_dir in "$HLS_DIR"/*/; do
            if [ -d "$stream_dir" ]; then
                local stream_name=$(basename "$stream_dir")
                local stream_stats=$(get_file_stats "$stream_dir")
                log "  $stream_name: $stream_stats"
            fi
        done
    fi
    log "========================="
}

# Main cleanup function
cleanup_all() {
    local timeframe="$1"
    log "Starting full system cleanup (timeframe: $timeframe)"
    
    cleanup_hls "$timeframe"
    cleanup_recordings "$timeframe"
    if [ "$timeframe" != "hour" ]; then  # Don't cleanup logs too frequently
        cleanup_logs "$timeframe"
    fi
    
    log "Full system cleanup completed"
    disk_usage_report
}

# Emergency cleanup (for critical disk space)
emergency_cleanup() {
    log "EMERGENCY CLEANUP INITIATED - Critical disk space"
    
    # Aggressive cleanup
    cleanup_hls "all"
    cleanup_recordings "day"
    cleanup_logs "week"
    
    # Additional cleanup
    log "Cleaning temporary files..."
    find /tmp -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "core.*" -type f -delete 2>/dev/null || true
    
    log "Emergency cleanup completed"
    disk_usage_report
}

# Show help
show_help() {
    echo "Thunderbird Streaming Platform - System Cleanup Script"
    echo ""
    echo "Usage: $0 [type] [timeframe]"
    echo ""
    echo "Types:"
    echo "  hls         - Clean HLS segments only"
    echo "  recordings  - Clean recording files only"
    echo "  logs        - Clean log files only"
    echo "  all         - Clean all file types"
    echo "  emergency   - Emergency cleanup (ignores timeframe)"
    echo "  report      - Show disk usage report only"
    echo ""
    echo "Timeframes:"
    echo "  hour        - Files older than 1 hour"
    echo "  day         - Files older than 1 day"
    echo "  week        - Files older than 1 week"
    echo "  all         - All files (careful!)"
    echo ""
    echo "Examples:"
    echo "  $0 hls hour           # Clean HLS segments older than 1 hour"
    echo "  $0 recordings day     # Clean recordings older than 1 day"
    echo "  $0 all week          # Clean all files older than 1 week"
    echo "  $0 emergency         # Emergency cleanup"
    echo "  $0 report            # Show disk usage report"
    echo ""
    echo "Log file: $LOG_FILE"
}

# Automatic cleanup based on disk usage
auto_cleanup() {
    local usage=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 90 ]; then
        log "Disk usage critical ($usage%) - initiating emergency cleanup"
        emergency_cleanup
    elif [ "$usage" -gt 80 ]; then
        log "Disk usage high ($usage%) - initiating aggressive cleanup"
        cleanup_all "day"
    elif [ "$usage" -gt 70 ]; then
        log "Disk usage moderate ($usage%) - initiating standard cleanup"
        cleanup_all "week"
    else
        log "Disk usage normal ($usage%) - no cleanup needed"
        disk_usage_report
    fi
}

# Main script logic
main() {
    local type="${1:-report}"
    local timeframe="${2:-day}"
    
    log "Cleanup script started (type: $type, timeframe: $timeframe)"
    
    case "$type" in
        "hls")
            cleanup_hls "$timeframe"
            ;;
        "recordings")
            cleanup_recordings "$timeframe"
            ;;
        "logs")
            cleanup_logs "$timeframe"
            ;;
        "all")
            cleanup_all "$timeframe"
            ;;
        "emergency")
            emergency_cleanup
            ;;
        "auto")
            auto_cleanup
            ;;
        "report")
            disk_usage_report
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "Invalid type: $type"
            show_help
            exit 1
            ;;
    esac
    
    log "Cleanup script completed"
}

# Run main function with all arguments
main "$@"