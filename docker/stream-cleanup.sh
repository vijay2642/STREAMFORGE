#!/bin/bash

# StreamForge Dynamic Stream Cleanup Service
# Handles automatic cleanup of old HLS segments and ended streams

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HLS_BASE_DIR="${HLS_DIR:-/tmp/streamforge/hls}"
LOG_FILE="/var/log/streamforge-cleanup.log"
DEFAULT_RETENTION_HOURS=24
SEGMENT_RETENTION_MINUTES=30
DRY_RUN="${DRY_RUN:-false}"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

success() {
    local message="✅ $1"
    echo -e "${GREEN}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

warning() {
    local message="⚠️  $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    local message="❌ $1"
    echo -e "${RED}${message}${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Check if stream is currently active
is_stream_active() {
    local stream_name="$1"
    local lock_file="/tmp/transcode_${stream_name}.lock"
    
    if [ -f "$lock_file" ]; then
        local pid=$(cat "$lock_file" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0  # Stream is active
        else
            # Stale lock file
            rm -f "$lock_file"
            return 1  # Stream is not active
        fi
    fi
    
    return 1  # Stream is not active
}

# Clean up old HLS segments
cleanup_old_segments() {
    local stream_dir="$1"
    local stream_name=$(basename "$stream_dir")
    
    log "Cleaning up old segments for stream: $stream_name"
    
    # Skip if stream is currently active
    if is_stream_active "$stream_name"; then
        log "Stream $stream_name is active, skipping segment cleanup"
        return 0
    fi
    
    local cleaned_count=0
    
    # Clean up .ts files older than retention period
    for quality_dir in "$stream_dir"/{720p,480p,360p}; do
        if [ -d "$quality_dir" ]; then
            local old_segments=$(find "$quality_dir" -name "*.ts" -mmin +$SEGMENT_RETENTION_MINUTES 2>/dev/null || true)
            
            if [ -n "$old_segments" ]; then
                if [ "$DRY_RUN" = "true" ]; then
                    log "DRY RUN: Would remove $(echo "$old_segments" | wc -l) old segments from $quality_dir"
                else
                    echo "$old_segments" | xargs rm -f
                    cleaned_count=$((cleaned_count + $(echo "$old_segments" | wc -l)))
                fi
            fi
        fi
    done
    
    if [ $cleaned_count -gt 0 ]; then
        success "Cleaned up $cleaned_count old segments for stream: $stream_name"
    fi
}

# Clean up ended streams
cleanup_ended_streams() {
    log "Checking for ended streams to clean up..."
    
    if [ ! -d "$HLS_BASE_DIR" ]; then
        warning "HLS directory does not exist: $HLS_BASE_DIR"
        return 0
    fi
    
    local cleaned_streams=0
    
    for stream_dir in "$HLS_BASE_DIR"/*; do
        if [ ! -d "$stream_dir" ]; then
            continue
        fi
        
        local stream_name=$(basename "$stream_dir")
        local metadata_file="$stream_dir/.stream_ended"
        
        # Skip active streams
        if is_stream_active "$stream_name"; then
            log "Stream $stream_name is active, skipping cleanup"
            continue
        fi
        
        # Check if stream has ended metadata
        if [ -f "$metadata_file" ]; then
            local ended_at=$(grep '"ended_at"' "$metadata_file" | cut -d'"' -f4 2>/dev/null || echo "")
            local retention_hours=$(grep '"retention_hours"' "$metadata_file" | cut -d':' -f2 | tr -d ' ,' 2>/dev/null || echo "$DEFAULT_RETENTION_HOURS")
            
            if [ -n "$ended_at" ]; then
                local ended_timestamp=$(date -d "$ended_at" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local age_hours=$(( (current_timestamp - ended_timestamp) / 3600 ))
                
                if [ $age_hours -ge $retention_hours ]; then
                    log "Stream $stream_name ended $age_hours hours ago (retention: ${retention_hours}h), cleaning up..."
                    
                    if [ "$DRY_RUN" = "true" ]; then
                        log "DRY RUN: Would remove stream directory: $stream_dir"
                    else
                        rm -rf "$stream_dir"
                        cleaned_streams=$((cleaned_streams + 1))
                        success "Cleaned up ended stream: $stream_name"
                    fi
                else
                    log "Stream $stream_name ended $age_hours hours ago, keeping (retention: ${retention_hours}h)"
                fi
            fi
        else
            # Check for streams without metadata that appear stale
            local last_activity=$(find "$stream_dir" -name "*.ts" -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
            
            if [ -n "$last_activity" ]; then
                local current_timestamp=$(date +%s)
                local age_hours=$(( (current_timestamp - ${last_activity%.*}) / 3600 ))
                
                if [ $age_hours -ge $((DEFAULT_RETENTION_HOURS * 2)) ]; then
                    warning "Found stale stream without metadata: $stream_name (last activity: ${age_hours}h ago)"
                    
                    if [ "$DRY_RUN" = "true" ]; then
                        log "DRY RUN: Would remove stale stream directory: $stream_dir"
                    else
                        rm -rf "$stream_dir"
                        cleaned_streams=$((cleaned_streams + 1))
                        success "Cleaned up stale stream: $stream_name"
                    fi
                fi
            else
                # Empty stream directory
                warning "Found empty stream directory: $stream_name"
                
                if [ "$DRY_RUN" = "true" ]; then
                    log "DRY RUN: Would remove empty stream directory: $stream_dir"
                else
                    rm -rf "$stream_dir"
                    cleaned_streams=$((cleaned_streams + 1))
                    success "Cleaned up empty stream directory: $stream_name"
                fi
            fi
        fi
        
        # Clean up old segments for remaining streams
        if [ -d "$stream_dir" ]; then
            cleanup_old_segments "$stream_dir"
        fi
    done
    
    if [ $cleaned_streams -gt 0 ]; then
        success "Cleaned up $cleaned_streams ended/stale streams"
    else
        log "No streams required cleanup"
    fi
}

# Generate cleanup report
generate_cleanup_report() {
    local total_streams=0
    local active_streams=0
    local ended_streams=0
    local total_size=0
    
    if [ -d "$HLS_BASE_DIR" ]; then
        for stream_dir in "$HLS_BASE_DIR"/*; do
            if [ -d "$stream_dir" ]; then
                total_streams=$((total_streams + 1))
                local stream_name=$(basename "$stream_dir")
                
                if is_stream_active "$stream_name"; then
                    active_streams=$((active_streams + 1))
                elif [ -f "$stream_dir/.stream_ended" ]; then
                    ended_streams=$((ended_streams + 1))
                fi
                
                local dir_size=$(du -sb "$stream_dir" 2>/dev/null | cut -f1 || echo "0")
                total_size=$((total_size + dir_size))
            fi
        done
    fi
    
    local total_size_mb=$((total_size / 1024 / 1024))
    
    log "Cleanup Report:"
    log "  Total streams: $total_streams"
    log "  Active streams: $active_streams"
    log "  Ended streams: $ended_streams"
    log "  Total storage used: ${total_size_mb}MB"
}

# Main cleanup function
main() {
    local mode="${1:-normal}"
    
    case "$mode" in
        "dry-run")
            DRY_RUN="true"
            log "Running in DRY RUN mode - no files will be deleted"
            ;;
        "force")
            log "Running in FORCE mode - aggressive cleanup"
            SEGMENT_RETENTION_MINUTES=5
            DEFAULT_RETENTION_HOURS=1
            ;;
        "normal")
            log "Running normal cleanup"
            ;;
        *)
            echo "Usage: $0 [normal|dry-run|force]"
            exit 1
            ;;
    esac
    
    echo -e "${BLUE}🧹 StreamForge Stream Cleanup${NC}"
    echo -e "${BLUE}=============================${NC}"
    echo
    
    cleanup_ended_streams
    generate_cleanup_report
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}📝 This was a dry run - no files were actually deleted${NC}"
    else
        echo -e "${GREEN}🎉 Cleanup completed successfully!${NC}"
    fi
}

# Run main function
main "$@"
