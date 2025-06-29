package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// HLSServer serves HLS files with optimized CORS and caching
type HLSServer struct {
	hlsDir string
}

// NewHLSServer creates a new HLS server instance
func NewHLSServer(hlsDir string) *HLSServer {
	return &HLSServer{
		hlsDir: hlsDir,
	}
}

// OptimizedCORSMiddleware provides CORS headers optimized for HLS streaming
func OptimizedCORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Essential CORS headers for HLS
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, HEAD")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "*")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")

		// Optimized caching based on file type
		path := c.Request.URL.Path
		
		if strings.HasSuffix(path, ".m3u8") {
			// Short cache for playlists (5 seconds) - prevents stale playlists
			c.Writer.Header().Set("Cache-Control", "max-age=5, no-cache")
			c.Writer.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		} else if strings.HasSuffix(path, ".ts") {
			// Longer cache for segments (2 minutes) - segments never change once created
			c.Writer.Header().Set("Cache-Control", "max-age=120, public")
			c.Writer.Header().Set("Content-Type", "video/mp2t")
			// Enable range requests for better seeking performance
			c.Writer.Header().Set("Accept-Ranges", "bytes")
		} else {
			// No cache for other files
			c.Writer.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		}

		c.Writer.Header().Set("Pragma", "no-cache")
		c.Writer.Header().Set("Expires", "0")

		// Handle preflight OPTIONS requests
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// ServeHLSFile serves HLS files with optimized headers
func (s *HLSServer) ServeHLSFile(c *gin.Context) {
	// Get the file path from the URL
	requestedPath := c.Param("filepath")
	
	// Clean the path to prevent directory traversal
	cleanPath := filepath.Clean(requestedPath)
	if strings.Contains(cleanPath, "..") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file path"})
		return
	}

	// Construct full file path
	fullPath := filepath.Join(s.hlsDir, cleanPath)

	// Check if file exists
	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Serve the file
	c.File(fullPath)
}

// GetHLSDirectory lists available HLS streams
func (s *HLSServer) GetHLSDirectory(c *gin.Context) {
	streams := []gin.H{}

	if entries, err := os.ReadDir(s.hlsDir); err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				streamName := entry.Name()
				streamPath := filepath.Join(s.hlsDir, streamName)
				
				// Check if master playlist exists
				masterPlaylist := filepath.Join(streamPath, "master.m3u8")
				status := "inactive"
				lastUpdate := ""
				fileCount := 0

				if _, err := os.Stat(masterPlaylist); err == nil {
					if info, err := os.Stat(masterPlaylist); err == nil {
						lastUpdate = info.ModTime().Format(time.RFC3339)
						if time.Since(info.ModTime()) < 30*time.Second {
							status = "active"
						}
					}
				}

				// Count files in stream directory
				if files, err := os.ReadDir(streamPath); err == nil {
					fileCount = len(files)
				}

				streams = append(streams, gin.H{
					"name":        streamName,
					"status":      status,
					"last_update": lastUpdate,
					"file_count":  fileCount,
					"endpoints": gin.H{
						"master":   fmt.Sprintf("/hls/%s/master.m3u8", streamName),
						"720p":     fmt.Sprintf("/hls/%s/720p/playlist.m3u8", streamName),
						"480p":     fmt.Sprintf("/hls/%s/480p/playlist.m3u8", streamName),
						"360p":     fmt.Sprintf("/hls/%s/360p/playlist.m3u8", streamName),
					},
				})
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    "success",
		"streams":   streams,
		"count":     len(streams),
		"directory": s.hlsDir,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// HealthCheck provides server health status
func (s *HLSServer) HealthCheck(c *gin.Context) {
	// Check if HLS directory is accessible
	accessible := false
	if _, err := os.Stat(s.hlsDir); err == nil {
		accessible = true
	}

	c.JSON(http.StatusOK, gin.H{
		"status":         "healthy",
		"service":        "hls-server",
		"hls_directory":  s.hlsDir,
		"directory_accessible": accessible,
		"timestamp":      time.Now().UTC(),
		"version":        "2.0.0-go",
		"performance":    "optimized",
	})
}

// StreamStats provides statistics about streams
func (s *HLSServer) StreamStats(c *gin.Context) {
	streamName := c.Param("stream")
	streamPath := filepath.Join(s.hlsDir, streamName)

	if _, err := os.Stat(streamPath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Stream not found"})
		return
	}

	stats := gin.H{
		"stream":    streamName,
		"variants":  gin.H{},
		"total_size": int64(0),
	}

	variants := []string{"720p", "480p", "360p"}
	totalSize := int64(0)

	for _, variant := range variants {
		variantPath := filepath.Join(streamPath, variant)
		variantStats := gin.H{
			"name":         variant,
			"segment_count": 0,
			"size":         int64(0),
			"last_update":  "",
			"active":       false,
		}

		if files, err := os.ReadDir(variantPath); err == nil {
			segmentCount := 0
			variantSize := int64(0)
			var lastMod time.Time

			for _, file := range files {
				if strings.HasSuffix(file.Name(), ".ts") {
					segmentCount++
					if info, err := file.Info(); err == nil {
						variantSize += info.Size()
						if info.ModTime().After(lastMod) {
							lastMod = info.ModTime()
						}
					}
				}
			}

			variantStats["segment_count"] = segmentCount
			variantStats["size"] = variantSize
			totalSize += variantSize

			if !lastMod.IsZero() {
				variantStats["last_update"] = lastMod.Format(time.RFC3339)
				variantStats["active"] = time.Since(lastMod) < 30*time.Second
			}
		}

		stats["variants"].(gin.H)[variant] = variantStats
	}

	stats["total_size"] = totalSize
	stats["timestamp"] = time.Now().Format(time.RFC3339)

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   stats,
	})
}

func main() {
	port := "8085"
	hlsDir := "/tmp/hls_shared"

	// Override with environment variables
	if envPort := os.Getenv("PORT"); envPort != "" {
		port = envPort
	}
	if envHLSDir := os.Getenv("HLS_DIR"); envHLSDir != "" {
		hlsDir = envHLSDir
	}

	// Create HLS directory if it doesn't exist
	if err := os.MkdirAll(hlsDir, 0755); err != nil {
		log.Fatalf("Failed to create HLS directory: %v", err)
	}

	// Set Gin to production mode for better performance
	gin.SetMode(gin.ReleaseMode)

	// Create HLS server
	hlsServer := NewHLSServer(hlsDir)

	// Setup router
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(OptimizedCORSMiddleware())

	// API routes
	r.GET("/health", hlsServer.HealthCheck)
	r.GET("/streams", hlsServer.GetHLSDirectory)
	r.GET("/stats/:stream", hlsServer.StreamStats)

	// HLS file serving routes
	r.GET("/hls/*filepath", hlsServer.ServeHLSFile)
	r.HEAD("/hls/*filepath", hlsServer.ServeHLSFile) // Support HEAD requests for range queries

	// Root redirect to streams listing
	r.GET("/", func(c *gin.Context) {
		c.Redirect(http.StatusTemporaryRedirect, "/streams")
	})

	log.Printf("🎬 StreamForge HLS Server (Go) starting on 0.0.0.0:%s", port)
	log.Printf("📂 Serving HLS files from: %s", hlsDir)
	log.Printf("⚡ Performance optimized - Python eliminated!")
	log.Printf("🌐 Server endpoints:")
	log.Printf("   - Health: http://0.0.0.0:%s/health", port)
	log.Printf("   - Streams: http://0.0.0.0:%s/streams", port)
	log.Printf("   - HLS Files: http://0.0.0.0:%s/hls/*", port)

	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("Failed to start HLS server: %v", err)
	}
}