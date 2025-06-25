package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/services/transcoder/internal/transcoder"
)

// Handler handles HTTP requests for the transcoder service
type Handler struct {
	transcoderManager *transcoder.Manager
}

// NewHandler creates a new handler instance
func NewHandler(transcoderManager *transcoder.Manager) *Handler {
	return &Handler{
		transcoderManager: transcoderManager,
	}
}

// HealthCheck handles health check requests
func (h *Handler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "transcoder",
		"timestamp": time.Now().UTC(),
		"version":   "1.0.0",
	})
}

// GetQualityProfiles handles requests to get available quality profiles
func (h *Handler) GetQualityProfiles(c *gin.Context) {
	profiles := h.transcoderManager.GetQualityProfiles()

	result := make([]gin.H, len(profiles))
	for i, profile := range profiles {
		result[i] = gin.H{
			"index":         i,
			"name":          profile.Name,
			"resolution":    profile.Resolution,
			"video_bitrate": profile.VideoBitrate,
			"max_bitrate":   profile.MaxBitrate,
			"buffer_size":   profile.BufSize,
			"hls_path":      fmt.Sprintf("/%d/index.m3u8", i),
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
		"count":   len(result),
	})
}

// StartTranscoder handles requests to start transcoding for a stream
func (h *Handler) StartTranscoder(c *gin.Context) {
	streamKey := c.Param("streamKey")

	if streamKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "stream key is required",
		})
		return
	}

	err := h.transcoderManager.StartTranscoder(streamKey)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Transcoder started successfully",
		"stream_key": streamKey,
		"hls_url":    "/hls/" + streamKey + "/master.m3u8",
		"endpoints": gin.H{
			"master_playlist": "/hls/" + streamKey + "/master.m3u8",
			"status":          "/transcode/status/" + streamKey,
			"stop":            "/transcode/stop/" + streamKey,
		},
	})
}

// StopTranscoder handles requests to stop transcoding for a stream
func (h *Handler) StopTranscoder(c *gin.Context) {
	streamKey := c.Param("streamKey")

	if streamKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "stream key is required",
		})
		return
	}

	err := h.transcoderManager.StopTranscoder(streamKey)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Transcoder stopped successfully",
		"stream_key": streamKey,
	})
}

// GetTranscoderStatus handles requests to get transcoder status for a stream
func (h *Handler) GetTranscoderStatus(c *gin.Context) {
	streamKey := c.Param("streamKey")

	if streamKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "stream key is required",
		})
		return
	}

	process, exists := h.transcoderManager.GetStatus(streamKey)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "transcoder not found for stream key",
		})
		return
	}

	// Calculate uptime
	uptime := time.Since(process.StartTime)

	// Build quality URLs
	qualities := make([]gin.H, len(process.Qualities))
	for i, quality := range process.Qualities {
		qualities[i] = gin.H{
			"index":      i,
			"name":       quality.Name,
			"resolution": quality.Resolution,
			"bitrate":    quality.VideoBitrate,
			"url":        "/hls/" + streamKey + "/" + fmt.Sprintf("%d", i) + "/index.m3u8",
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"stream_key":     streamKey,
			"status":         process.Status,
			"start_time":     process.StartTime,
			"uptime":         uptime.String(),
			"uptime_seconds": int(uptime.Seconds()),
			"output_dir":     process.OutputDir,
			"pid":            process.PID,
			"hls_master":     "/hls/" + streamKey + "/master.m3u8",
			"qualities":      qualities,
		},
	})
}

// GetActiveTranscoders handles requests to get all active transcoders
func (h *Handler) GetActiveTranscoders(c *gin.Context) {
	activeTranscoders := h.transcoderManager.GetActiveTranscoders()

	result := make([]gin.H, 0, len(activeTranscoders))
	for streamKey, process := range activeTranscoders {
		uptime := time.Since(process.StartTime)

		result = append(result, gin.H{
			"stream_key":     streamKey,
			"status":         process.Status,
			"start_time":     process.StartTime,
			"uptime":         uptime.String(),
			"uptime_seconds": int(uptime.Seconds()),
			"output_dir":     process.OutputDir,
			"pid":            process.PID,
			"hls_master":     "/hls/" + streamKey + "/master.m3u8",
			"quality_count":  len(process.Qualities),
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
		"count":   len(result),
	})
}
