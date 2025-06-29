package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/services/transcoder/internal/handlers"
	"github.com/streamforge/platform/services/transcoder/internal/transcoder"
)

// CORS middleware
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// Custom HLS file handler with CORS
func HLSFileHandler(outputDir string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Set CORS headers for HLS files
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Range, Origin, X-Requested-With, Content-Type, Accept, Authorization, Cache-Control")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")

		// Handle preflight OPTIONS request
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		// Set appropriate content types for HLS files
		filePath := c.Param("filepath")
		ext := filepath.Ext(filePath)

		switch ext {
		case ".m3u8":
			c.Writer.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		case ".ts":
			c.Writer.Header().Set("Content-Type", "video/mp2t")
		}

		// Serve the file
		fullPath := filepath.Join(outputDir, filePath)
		c.File(fullPath)
	}
}

func main() {
	port := flag.String("port", "8083", "HTTP server port")
	rtmpURL := flag.String("rtmp-url", "rtmp://localhost:1935/live", "RTMP server URL")
	outputDir := flag.String("output-dir", "/tmp/hls_shared", "HLS output directory")
	flag.Parse()

	// Override with environment variables if set
	if envPort := os.Getenv("PORT"); envPort != "" {
		*port = envPort
	}
	if envRTMP := os.Getenv("RTMP_URL"); envRTMP != "" {
		*rtmpURL = envRTMP
	}
	if envOutputDir := os.Getenv("OUTPUT_DIR"); envOutputDir != "" {
		*outputDir = envOutputDir
	}

	log.Printf("🎬 StreamForge Transcoder Service")
	log.Printf("Port: %s", *port)
	log.Printf("RTMP URL: %s", *rtmpURL)
	log.Printf("Output Directory: %s", *outputDir)

	// Initialize transcoder manager
	transcoderManager := transcoder.NewManager(*rtmpURL, *outputDir)

	// Initialize handlers
	handler := handlers.NewHandler(transcoderManager)

	// Setup Gin router
	router := gin.Default()

	// Add CORS middleware
	router.Use(CORSMiddleware())

	// Handle OPTIONS requests globally
	router.OPTIONS("/*path", func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Range, Origin, X-Requested-With, Content-Type, Accept, Authorization, Cache-Control")
		c.AbortWithStatus(204)
	})

	// Health check
	router.GET("/health", handler.HealthCheck)

	// Quality profiles endpoint
	router.GET("/qualities", handler.GetQualityProfiles)

	// Transcoder management endpoints
	router.POST("/transcode/start/:streamKey", handler.StartTranscoder)
	router.POST("/transcode/stop/:streamKey", handler.StopTranscoder)
	router.GET("/transcode/status/:streamKey", handler.GetTranscoderStatus)
	router.GET("/transcode/active", handler.GetActiveTranscoders)

	// NGINX callback endpoints (called by NGINX on_publish/on_publish_done)
	router.POST("/api/streams/start/:streamKey", handler.StartTranscoder)
	router.POST("/api/streams/stop/:streamKey", handler.StopTranscoder)
	router.GET("/api/streams/status/:streamKey", handler.GetTranscoderStatus)

	// HLS file serving with CORS support
	router.GET("/hls/*filepath", HLSFileHandler(*outputDir))

	// Start server
	server := &http.Server{
		Addr:    ":" + *port,
		Handler: router,
	}

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan

		log.Printf("Shutting down transcoder service...")

		// Stop all active transcoders
		transcoderManager.StopAll()

		// Shutdown HTTP server
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}

		os.Exit(0)
	}()

	log.Printf("🚀 Transcoder service starting on port %s", *port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Failed to start server: %v", err)
	}
}
