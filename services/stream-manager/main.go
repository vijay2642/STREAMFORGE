package main

import (
	"context"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
)

// RTMP Statistics structures
type RTMPStats struct {
	XMLName xml.Name `xml:"rtmp"`
	Server  Server   `xml:"server"`
}

type Server struct {
	Application Application `xml:"application"`
}

type Application struct {
	Name string `xml:"n"`
	Live Live   `xml:"live"`
}

type Live struct {
	Streams  []Stream `xml:"stream"`
	NClients int      `xml:"nclients"`
}

type Stream struct {
	Name       string    `xml:"n"`
	Time       int       `xml:"time"`
	BWIn       int       `xml:"bw_in"`
	BWOut      int       `xml:"bw_out"`
	NClients   int       `xml:"nclients"`
	Publishing *struct{} `xml:"publishing"`
	Active     *struct{} `xml:"active"`
}

// StreamManager manages active streams and transcoders
type StreamManager struct {
	activeStreams map[string]*StreamInfo
	mutex         sync.RWMutex
	nginxStatURL  string
	transcoderURL string
	outputDir     string
}

type StreamInfo struct {
	Name          string    `json:"name"`
	Active        bool      `json:"active"`
	Publishing    bool      `json:"publishing"`
	Clients       int       `json:"clients"`
	LastSeen      time.Time `json:"last_seen"`
	TranscoderPID int       `json:"transcoder_pid"`
	BWIn          int       `json:"bw_in"`
	BWOut         int       `json:"bw_out"`
}

func NewStreamManager() *StreamManager {
	nginxURL := os.Getenv("NGINX_URL")
	if nginxURL == "" {
		nginxURL = "http://nginx-rtmp:8080"
	}

	transcoderURL := os.Getenv("TRANSCODER_URL")
	if transcoderURL == "" {
		transcoderURL = "http://transcoder:8083"
	}

	return &StreamManager{
		activeStreams: make(map[string]*StreamInfo),
		nginxStatURL:  nginxURL + "/stat",
		transcoderURL: transcoderURL,
		outputDir:     "/tmp/hls_shared",
	}
}

func (sm *StreamManager) Start() {
	log.Println("🚀 Starting Stream Manager...")

	// Monitor streams every 5 seconds
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			sm.checkStreams()
		}
	}
}

func (sm *StreamManager) checkStreams() {
	stats, err := sm.fetchNginxStats()
	if err != nil {
		log.Printf("❌ Error fetching NGINX stats: %v", err)
		return
	}

	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	// Mark all current streams as not seen
	for name := range sm.activeStreams {
		sm.activeStreams[name].Active = false
	}

	log.Printf("🔍 Found %d streams in NGINX stats", len(stats.Server.Application.Live.Streams))

	// Process current streams from NGINX
	for _, stream := range stats.Server.Application.Live.Streams {
		isPublishing := stream.Publishing != nil
		isActive := stream.Active != nil

		// Fix: Properly trim whitespace and handle empty stream names
		streamName := strings.TrimSpace(stream.Name)
		if streamName == "" {
			log.Printf("🔍 Skipping empty stream name")
			continue
		}

		log.Printf("🔍 Processing stream: name='%s', publishing=%v, active=%v", streamName, isPublishing, isActive)

		if isPublishing {
			if existing, exists := sm.activeStreams[streamName]; exists {
				// Update existing stream
				existing.Active = isActive
				existing.Publishing = isPublishing
				existing.Clients = stream.NClients
				existing.LastSeen = time.Now()
				existing.BWIn = stream.BWIn
				existing.BWOut = stream.BWOut
				log.Printf("📡 Updated stream: %s (clients: %d, bw_in: %d)", streamName, stream.NClients, stream.BWIn)
			} else {
				// New stream detected
				streamInfo := &StreamInfo{
					Name:       streamName,
					Active:     isActive,
					Publishing: isPublishing,
					Clients:    stream.NClients,
					LastSeen:   time.Now(),
					BWIn:       stream.BWIn,
					BWOut:      stream.BWOut,
				}
				sm.activeStreams[streamName] = streamInfo
				log.Printf("🎬 New stream detected: %s", streamName)

				// Start transcoder for new stream
				go sm.startTranscoder(streamName)
			}
		}
	}

	// Stop transcoders for inactive streams
	for name, streamInfo := range sm.activeStreams {
		if !streamInfo.Active && time.Since(streamInfo.LastSeen) > 30*time.Second {
			log.Printf("🛑 Stream %s inactive, stopping transcoder", name)
			sm.stopTranscoder(name)
			delete(sm.activeStreams, name)
		}
	}
}

func (sm *StreamManager) fetchNginxStats() (*RTMPStats, error) {
	resp, err := http.Get(sm.nginxStatURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// Debug: log the raw XML to see what we're getting
	log.Printf("🔍 Raw XML length: %d bytes", len(body))

	var stats RTMPStats
	err = xml.Unmarshal(body, &stats)
	if err != nil {
		log.Printf("❌ XML unmarshal error: %v", err)
		return nil, err
	}

	// Fix stream names using regex since XML parsing isn't working correctly
	sm.fixStreamNames(&stats, string(body))

	// Debug: log what we parsed
	log.Printf("🔍 Parsed application name: '%s'", stats.Server.Application.Name)
	log.Printf("🔍 Parsed %d streams", len(stats.Server.Application.Live.Streams))
	for i, stream := range stats.Server.Application.Live.Streams {
		log.Printf("🔍 Stream %d: name='%s' (len=%d)", i, stream.Name, len(stream.Name))
	}

	return &stats, nil
}

func (sm *StreamManager) fixStreamNames(stats *RTMPStats, xmlContent string) {
	// Use regex to extract stream names from XML - handle any characters between tags
	re := regexp.MustCompile(`<n>([^<]+)</n>`)
	matches := re.FindAllStringSubmatch(xmlContent, -1)

	log.Printf("🔍 Regex found %d stream name matches", len(matches))

	// Debug: test the regex pattern manually
	testPattern := `<stream>
<n>stream1</n>`
	testRe := regexp.MustCompile(`<n>([^<]+)</n>`)
	testMatches := testRe.FindAllStringSubmatch(testPattern, -1)
	log.Printf("🔍 Test regex found %d matches", len(testMatches))
	if len(testMatches) > 0 {
		log.Printf("🔍 Test match: '%s'", testMatches[0][1])
	}

	// Debug: show different parts of XML to find stream names
	if len(xmlContent) > 1000 {
		log.Printf("🔍 XML start: %s", xmlContent[0:200])
		log.Printf("🔍 XML middle: %s", xmlContent[500:700])

		// Look for stream patterns in the XML
		streamIndex := strings.Index(xmlContent, "<stream>")
		if streamIndex >= 0 && streamIndex+300 < len(xmlContent) {
			log.Printf("🔍 Stream section: %s", xmlContent[streamIndex:streamIndex+300])
		}
	}

	for i, match := range matches {
		if i < len(stats.Server.Application.Live.Streams) && len(match) > 1 {
			streamName := strings.TrimSpace(match[1])
			stats.Server.Application.Live.Streams[i].Name = streamName
			log.Printf("🔍 Fixed stream %d name to: '%s'", i, streamName)
		}
	}
}

func (sm *StreamManager) startTranscoder(streamName string) {
	log.Printf("🎬 Starting transcoder for stream: %s", streamName)

	// Call the transcoder service API instead of the old script
	url := fmt.Sprintf("%s/transcode/start/%s", sm.transcoderURL, streamName)
	resp, err := http.Post(url, "application/json", nil)
	if err != nil {
		log.Printf("❌ Failed to start transcoder for %s: %v", streamName, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		log.Printf("✅ Transcoder started for %s via API", streamName)
	} else {
		log.Printf("❌ Transcoder API returned status %d for %s", resp.StatusCode, streamName)
	}
}

func (sm *StreamManager) stopTranscoder(streamName string) {
	log.Printf("🛑 Stopping transcoder for stream: %s", streamName)

	// Call the transcoder service API to stop
	url := fmt.Sprintf("%s/transcode/stop/%s", sm.transcoderURL, streamName)
	resp, err := http.Post(url, "application/json", nil)
	if err != nil {
		log.Printf("❌ Failed to stop transcoder for %s: %v", streamName, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		log.Printf("✅ Transcoder stopped for %s via API", streamName)
	} else {
		log.Printf("❌ Transcoder API returned status %d for %s", resp.StatusCode, streamName)
	}
}

// HTTP Handlers
func (sm *StreamManager) getActiveStreams(c *gin.Context) {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()

	streams := make(map[string]*StreamInfo)
	for name, info := range sm.activeStreams {
		streams[name] = info
	}

	c.JSON(http.StatusOK, gin.H{
		"active_streams": streams,
		"total_count":    len(streams),
	})
}

func (sm *StreamManager) getStreamStatus(c *gin.Context) {
	streamName := c.Param("stream")

	sm.mutex.RLock()
	streamInfo, exists := sm.activeStreams[streamName]
	sm.mutex.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Stream not found"})
		return
	}

	c.JSON(http.StatusOK, streamInfo)
}

func main() {
	streamManager := NewStreamManager()

	// Start stream monitoring in background
	go streamManager.Start()

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	// CORS middleware
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// API routes
	api := router.Group("/api/v1")
	{
		api.GET("/streams", streamManager.getActiveStreams)
		api.GET("/streams/:stream", streamManager.getStreamStatus)
	}

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// Start HTTP server
	server := &http.Server{
		Addr:    ":8084",
		Handler: router,
	}

	go func() {
		log.Println("🌐 Stream Manager API starting on port 8084")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start HTTP server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down Stream Manager...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("❌ HTTP server forced to shutdown: %v", err)
	}

	log.Println("✅ Stream Manager stopped")
}
