package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
	"github.com/streamforge/platform/services/stream-processing/internal/processor"
)

// Handler handles HTTP requests for the stream processing service
type Handler struct {
	config    *config.Config
	processor *processor.Processor
}

// NewHandler creates a new handler instance
func NewHandler(cfg *config.Config, proc *processor.Processor) *Handler {
	return &Handler{
		config:    cfg,
		processor: proc,
	}
}

// HealthCheck handles health check requests
func (h *Handler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":  "healthy",
		"service": "stream-processing",
	})
}

// ProcessStream handles stream processing requests
func (h *Handler) ProcessStream(c *gin.Context) {
	streamKey := c.Param("streamKey")

	var req struct {
		InputURL string                   `json:"input_url" binding:"required"`
		Formats  []processor.OutputFormat `json:"formats"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	// Use default formats if none specified
	if len(req.Formats) == 0 {
		req.Formats = h.processor.GetSupportedFormats()
	}

	if err := h.processor.ProcessStream(streamKey, req.InputURL, req.Formats); err != nil {
		logger.Error("Failed to start processing:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	logger.WithField("stream_key", streamKey).Info("Processing started")

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Processing started",
		"stream_key": streamKey,
		"formats":    req.Formats,
	})
}

// StopProcessing handles stop processing requests
func (h *Handler) StopProcessing(c *gin.Context) {
	streamKey := c.Param("streamKey")

	if err := h.processor.StopProcessing(streamKey); err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	logger.WithField("stream_key", streamKey).Info("Processing stopped")

	c.JSON(http.StatusOK, gin.H{
		"success":    true,
		"message":    "Processing stopped",
		"stream_key": streamKey,
	})
}

// GetProcessingStatus returns the status of a processing job
func (h *Handler) GetProcessingStatus(c *gin.Context) {
	streamKey := c.Param("streamKey")

	job, err := h.processor.GetProcessingStatus(streamKey)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	var duration float64
	if job.EndTime != nil {
		duration = job.EndTime.Sub(job.StartTime).Seconds()
	} else {
		duration = job.StartTime.Sub(job.StartTime).Seconds()
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"stream_key":     job.StreamKey,
			"status":         job.Status,
			"input_url":      job.InputURL,
			"output_formats": job.OutputFormats,
			"start_time":     job.StartTime,
			"end_time":       job.EndTime,
			"duration":       duration,
			"stats":          job.Stats,
		},
	})
}

// GetActiveProcesses returns all active processing jobs
func (h *Handler) GetActiveProcesses(c *gin.Context) {
	processes := h.processor.GetActiveProcesses()

	result := make([]gin.H, 0, len(processes))
	for _, job := range processes {
		var duration float64
		if job.EndTime != nil {
			duration = job.EndTime.Sub(job.StartTime).Seconds()
		} else {
			duration = job.StartTime.Sub(job.StartTime).Seconds()
		}

		result = append(result, gin.H{
			"stream_key":     job.StreamKey,
			"status":         job.Status,
			"input_url":      job.InputURL,
			"output_formats": job.OutputFormats,
			"start_time":     job.StartTime,
			"end_time":       job.EndTime,
			"duration":       duration,
			"stats":          job.Stats,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
		"count":   len(result),
	})
}

// StartTranscoding handles transcoding requests
func (h *Handler) StartTranscoding(c *gin.Context) {
	var req struct {
		StreamKey  string                 `json:"stream_key" binding:"required"`
		InputURL   string                 `json:"input_url" binding:"required"`
		OutputPath string                 `json:"output_path" binding:"required"`
		Format     processor.OutputFormat `json:"format" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	// Start transcoding with single format
	formats := []processor.OutputFormat{req.Format}

	if err := h.processor.ProcessStream(req.StreamKey, req.InputURL, formats); err != nil {
		logger.Error("Failed to start transcoding:", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	logger.WithField("stream_key", req.StreamKey).Info("Transcoding started")

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"message":     "Transcoding started",
		"stream_key":  req.StreamKey,
		"input_url":   req.InputURL,
		"output_path": req.OutputPath,
		"format":      req.Format,
	})
}

// GetSupportedFormats returns supported output formats
func (h *Handler) GetSupportedFormats(c *gin.Context) {
	formats := h.processor.GetSupportedFormats()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    formats,
		"count":   len(formats),
	})
}
