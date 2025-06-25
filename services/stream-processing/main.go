package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
	"github.com/streamforge/platform/services/stream-processing/internal/handlers"
	"github.com/streamforge/platform/services/stream-processing/internal/processor"
)

func main() {
	// Load configuration
	cfg, err := config.Load("STREAM_PROCESSING")
	if err != nil {
		log.Fatal("Failed to load configuration:", err)
	}

	// Initialize logger
	logger.InitLogger(cfg.Logger.Level, cfg.Logger.Format)
	logger.Info("Starting Stream Processing Service")

	// Initialize stream processor
	streamProcessor := processor.NewProcessor(cfg)

	// Start background processing
	go func() {
		if err := streamProcessor.Start(); err != nil {
			logger.Fatal("Failed to start stream processor:", err)
		}
	}()

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	// Initialize handlers
	handler := handlers.NewHandler(cfg, streamProcessor)

	// Health check
	router.GET("/health", handler.HealthCheck)

	// Processing endpoints
	v1 := router.Group("/api/v1")
	{
		v1.POST("/process/:streamKey", handler.ProcessStream)
		v1.DELETE("/process/:streamKey", handler.StopProcessing)
		v1.GET("/process/:streamKey/status", handler.GetProcessingStatus)
		v1.GET("/process/active", handler.GetActiveProcesses)
		v1.POST("/transcode", handler.StartTranscoding)
		v1.GET("/formats", handler.GetSupportedFormats)
	}

	// Start HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
	}

	go func() {
		logger.Info("HTTP server starting on port", cfg.Server.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start HTTP server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down Stream Processing Service...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("HTTP server forced to shutdown:", err)
	}

	streamProcessor.Stop()
	logger.Info("Stream Processing Service stopped")
}
