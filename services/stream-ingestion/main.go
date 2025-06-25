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
	"github.com/streamforge/platform/services/stream-ingestion/internal/handlers"
	"github.com/streamforge/platform/services/stream-ingestion/internal/rtmp"
)

func main() {
	// Load configuration
	cfg, err := config.Load("STREAM_INGESTION")
	if err != nil {
		log.Fatal("Failed to load configuration:", err)
	}

	// Initialize logger
	logger.InitLogger(cfg.Logger.Level, cfg.Logger.Format)
	logger.Info("Starting Stream Ingestion Service")

	// Initialize RTMP server
	rtmpServer := rtmp.NewServer(cfg)
	go func() {
		if err := rtmpServer.Start(); err != nil {
			logger.Fatal("Failed to start RTMP server:", err)
		}
	}()

	// Setup HTTP server for health checks and management
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	// Initialize handlers
	handler := handlers.NewHandler(cfg, rtmpServer)

	// Health check
	router.GET("/health", handler.HealthCheck)

	// Stream management endpoints
	v1 := router.Group("/api/v1")
	{
		v1.POST("/streams/:streamKey/start", handler.StartStream)
		v1.POST("/streams/:streamKey/stop", handler.StopStream)
		v1.GET("/streams/:streamKey/status", handler.GetStreamStatus)
		v1.GET("/streams/active", handler.GetActiveStreams)
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

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down Stream Ingestion Service...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("HTTP server forced to shutdown:", err)
	}

	rtmpServer.Stop()
	logger.Info("Stream Ingestion Service stopped")
}
