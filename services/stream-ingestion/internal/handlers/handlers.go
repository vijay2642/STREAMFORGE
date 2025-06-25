package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
	"github.com/streamforge/platform/services/stream-ingestion/internal/rtmp"
)

// Handler handles HTTP requests for the stream ingestion service
type Handler struct {
	config     *config.Config
	rtmpServer *rtmp.Server
}

// NewHandler creates a new handler instance
func NewHandler(cfg *config.Config, rtmpServer *rtmp.Server) *Handler {
	return &Handler{
		config:     cfg,
		rtmpServer: rtmpServer,
	}
}

// HealthCheck handles health check requests
func (h *Handler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "stream-ingestion",
	})
}

// StartStream handles stream start requests
func (h *Handler) StartStream(c *gin.Context) {
	streamKey := c.Param("streamKey")

	logger.WithField("stream_key", streamKey).Info("Stream start requested")

	// In a real implementation, you would validate the stream key
	// and authenticate the user

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Stream start acknowledged",
		"stream_key": streamKey,
		"rtmp_url":   h.getRTMPURL(streamKey),
	})
}

// StopStream handles stream stop requests
func (h *Handler) StopStream(c *gin.Context) {
	streamKey := c.Param("streamKey")

	logger.WithField("stream_key", streamKey).Info("Stream stop requested")

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Stream stop acknowledged",
		"stream_key": streamKey,
	})
}

// GetStreamStatus returns the status of a specific stream
func (h *Handler) GetStreamStatus(c *gin.Context) {
	streamKey := c.Param("streamKey")

	stream, exists := h.rtmpServer.GetStream(streamKey)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "Stream not found",
		})
		return
	}

	stats := stream.GetStats()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"stream_key":   streamKey,
			"status":       "online",
			"viewer_count": stats.ViewerCount,
			"bytes_in":     stats.BytesIn,
			"bytes_out":    stats.BytesOut,
			"duration":     stats.Duration.Seconds(),
			"started_at":   stream.StartTime,
		},
	})
}

// GetActiveStreams returns all active streams
func (h *Handler) GetActiveStreams(c *gin.Context) {
	streams := h.rtmpServer.GetActiveStreams()

	result := make([]gin.H, 0, len(streams))

	for streamKey, stream := range streams {
		stats := stream.GetStats()
		result = append(result, gin.H{
			"stream_key":   streamKey,
			"status":       "online",
			"viewer_count": stats.ViewerCount,
			"bytes_in":     stats.BytesIn,
			"bytes_out":    stats.BytesOut,
			"duration":     stats.Duration.Seconds(),
			"started_at":   stream.StartTime,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
		"count":   len(result),
	})
}

// getRTMPURL generates the RTMP URL for streaming
func (h *Handler) getRTMPURL(streamKey string) string {
	return "rtmp://localhost:" +
		string(rune(h.config.Stream.RTMPPort)) +
		"/live/" + streamKey
}
