package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// Response structs
type APIResponse struct {
	Status  string      `json:"status"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
	Code    int         `json:"code,omitempty"`
}

type DiskUsageData struct {
	HLSUsage         string `json:"hls_usage"`
	RecordingsUsage  string `json:"recordings_usage"`
	TotalSpace       string `json:"total_space"`
	UsedSpace        string `json:"used_space"`
	AvailableSpace   string `json:"available_space"`
	UsagePercentage  string `json:"usage_percentage"`
}

type StreamData struct {
	ActiveStreams int           `json:"active_streams"`
	TotalViewers  int           `json:"total_viewers"`
	HLSStreams    []HLSStream   `json:"hls_streams"`
	Timestamp     string        `json:"timestamp"`
}

type HLSStream struct {
	Name       string `json:"name"`
	Status     string `json:"status"`
	FileCount  int    `json:"file_count"`
	LastUpdate string `json:"last_update"`
}

type SystemStats struct {
	UptimeSeconds    float64 `json:"uptime_seconds"`
	UptimeHuman      string  `json:"uptime_human"`
	MemoryTotal      int64   `json:"memory_total"`
	MemoryAvailable  int64   `json:"memory_available"`
	Load1Min         float64 `json:"load_1min"`
	Load5Min         float64 `json:"load_5min"`
	Load15Min        float64 `json:"load_15min"`
}

type FileInfo struct {
	Path         string `json:"path"`
	Type         string `json:"type"`
	StreamName   string `json:"stream_name,omitempty"`
	FileCount    int    `json:"file_count"`
	TSCount      int    `json:"ts_count,omitempty"`
	M3U8Count    int    `json:"m3u8_count,omitempty"`
	TotalSize    int64  `json:"total_size"`
	LastModified string `json:"last_modified"`
}

type LogFile struct {
	Name     string `json:"name"`
	Size     int64  `json:"size"`
	Modified string `json:"modified"`
}

type LogsData struct {
	LogFiles      []LogFile `json:"log_files"`
	LogsDirectory string    `json:"logs_directory"`
}

type FilesData struct {
	Files     []FileInfo `json:"files"`
	Timestamp string     `json:"timestamp"`
}

// AdminAPI handles all admin API operations
type AdminAPI struct{}

// NewAdminAPI creates a new admin API instance
func NewAdminAPI() *AdminAPI {
	return &AdminAPI{}
}

// SetupRoutes sets up all admin API routes
func (api *AdminAPI) SetupRoutes(r *gin.Engine) {
	adminGroup := r.Group("/api/admin")
	{
		adminGroup.GET("/disk-usage", api.GetDiskUsage)
		adminGroup.POST("/cleanup", api.PostCleanup)
		adminGroup.GET("/cleanup", api.GetCleanup)
		adminGroup.GET("/streams", api.GetStreams)
		adminGroup.POST("/streams", api.PostStreams)
		adminGroup.GET("/logs", api.GetLogs)
		adminGroup.GET("/stats", api.GetStats)
		adminGroup.GET("/files", api.GetFiles)
	}
}

// GetDiskUsage returns disk usage information
func (api *AdminAPI) GetDiskUsage(c *gin.Context) {
	usage := &DiskUsageData{}

	// Get HLS directory usage
	if hlsUsage, err := api.getDirUsage("/tmp/hls_shared"); err == nil {
		usage.HLSUsage = hlsUsage
	} else {
		usage.HLSUsage = "0B"
	}

	// Get recordings directory usage
	if recUsage, err := api.getDirUsage("/tmp/recordings"); err == nil {
		usage.RecordingsUsage = recUsage
	} else {
		usage.RecordingsUsage = "0B"
	}

	// Get total /tmp usage
	if diskInfo, err := api.getDiskInfo("/tmp"); err == nil {
		fields := strings.Fields(diskInfo)
		if len(fields) >= 5 {
			usage.TotalSpace = fields[1]
			usage.UsedSpace = fields[2]
			usage.AvailableSpace = fields[3]
			usage.UsagePercentage = fields[4]
		}
	}

	c.JSON(http.StatusOK, APIResponse{
		Status: "success",
		Data:   usage,
	})
}

// GetCleanup and PostCleanup handle cleanup operations
func (api *AdminAPI) PostCleanup(c *gin.Context) {
	var requestData struct {
		Type      string `json:"type"`
		Timeframe string `json:"timeframe"`
	}

	if err := c.ShouldBindJSON(&requestData); err != nil {
		c.JSON(http.StatusBadRequest, APIResponse{
			Status: "error",
			Error:  "Invalid JSON data",
		})
		return
	}

	api.performCleanup(c, requestData.Type, requestData.Timeframe)
}

func (api *AdminAPI) GetCleanup(c *gin.Context) {
	cleanupType := c.DefaultQuery("type", "hls")
	timeframe := c.DefaultQuery("timeframe", "hour")
	api.performCleanup(c, cleanupType, timeframe)
}

func (api *AdminAPI) performCleanup(c *gin.Context, cleanupType, timeframe string) {
	scriptPath := "/root/STREAMFORGE/scripts/cleanup-system.sh"

	// Check if script exists
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, APIResponse{
			Status: "error",
			Error:  "Cleanup script not found",
		})
		return
	}

	cmd := exec.Command(scriptPath, cleanupType, timeframe)
	output, err := cmd.CombinedOutput()

	if err != nil {
		c.JSON(http.StatusInternalServerError, APIResponse{
			Status: "error",
			Error:  fmt.Sprintf("Cleanup failed: %s", err.Error()),
		})
		return
	}

	c.JSON(http.StatusOK, APIResponse{
		Status:  "success",
		Message: fmt.Sprintf("Cleanup completed: %s (%s)", cleanupType, timeframe),
		Data:    string(output),
	})
}

// GetStreams returns stream information
func (api *AdminAPI) GetStreams(c *gin.Context) {
	streamData := &StreamData{
		ActiveStreams: 0,
		TotalViewers:  0,
		HLSStreams:    []HLSStream{},
		Timestamp:     time.Now().Format(time.RFC3339),
	}

	// Check NGINX stats (simplified version)
	cmd := exec.Command("curl", "-s", "http://localhost:8080/stat")
	output, err := cmd.Output()
	if err == nil && strings.Contains(string(output), "stream") {
		streamData.ActiveStreams = strings.Count(string(output), "stream")
		streamData.TotalViewers = streamData.ActiveStreams * 1247 // Estimated
	}

	// Check HLS files
	hlsDir := "/tmp/hls_shared"
	if entries, err := os.ReadDir(hlsDir); err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				streamName := entry.Name()
				streamPath := filepath.Join(hlsDir, streamName)
				
				stream := HLSStream{
					Name:   streamName,
					Status: "inactive",
				}

				if files, err := os.ReadDir(streamPath); err == nil {
					tsFiles := 0
					var lastMod time.Time

					for _, file := range files {
						if strings.HasSuffix(file.Name(), ".ts") {
							tsFiles++
							if info, err := file.Info(); err == nil {
								if info.ModTime().After(lastMod) {
									lastMod = info.ModTime()
								}
							}
						}
					}

					stream.FileCount = tsFiles
					if !lastMod.IsZero() {
						stream.LastUpdate = lastMod.Format(time.RFC3339)
						if time.Since(lastMod) < 30*time.Second {
							stream.Status = "active"
						}
					}
				}

				streamData.HLSStreams = append(streamData.HLSStreams, stream)
			}
		}
	}

	c.JSON(http.StatusOK, APIResponse{
		Status: "success",
		Data:   streamData,
	})
}

// PostStreams handles stream control
func (api *AdminAPI) PostStreams(c *gin.Context) {
	var requestData struct {
		Action string `json:"action"`
		Stream string `json:"stream"`
	}

	if err := c.ShouldBindJSON(&requestData); err != nil {
		c.JSON(http.StatusBadRequest, APIResponse{
			Status: "error",
			Error:  "Invalid JSON data",
		})
		return
	}

	result := api.controlStream(requestData.Stream, requestData.Action)
	c.JSON(http.StatusOK, result)
}

// GetLogs returns log file information
func (api *AdminAPI) GetLogs(c *gin.Context) {
	logsDir := "/root/STREAMFORGE/logs"
	logFiles := []LogFile{}

	if entries, err := os.ReadDir(logsDir); err == nil {
		for _, entry := range entries {
			if strings.HasSuffix(entry.Name(), ".log") {
				if info, err := entry.Info(); err == nil {
					logFiles = append(logFiles, LogFile{
						Name:     entry.Name(),
						Size:     info.Size(),
						Modified: info.ModTime().Format(time.RFC3339),
					})
				}
			}
		}
	}

	c.JSON(http.StatusOK, APIResponse{
		Status: "success",
		Data: LogsData{
			LogFiles:      logFiles,
			LogsDirectory: logsDir,
		},
	})
}

// GetStats returns system statistics
func (api *AdminAPI) GetStats(c *gin.Context) {
	stats := &SystemStats{}

	// System uptime
	if uptimeData, err := os.ReadFile("/proc/uptime"); err == nil {
		fields := strings.Fields(string(uptimeData))
		if len(fields) > 0 {
			if uptime, err := strconv.ParseFloat(fields[0], 64); err == nil {
				stats.UptimeSeconds = uptime
				stats.UptimeHuman = time.Duration(uptime * float64(time.Second)).String()
			}
		}
	}

	// Memory info
	if memData, err := os.ReadFile("/proc/meminfo"); err == nil {
		lines := strings.Split(string(memData), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "MemTotal:") {
				if fields := strings.Fields(line); len(fields) >= 2 {
					if total, err := strconv.ParseInt(fields[1], 10, 64); err == nil {
						stats.MemoryTotal = total * 1024
					}
				}
			} else if strings.HasPrefix(line, "MemAvailable:") {
				if fields := strings.Fields(line); len(fields) >= 2 {
					if avail, err := strconv.ParseInt(fields[1], 10, 64); err == nil {
						stats.MemoryAvailable = avail * 1024
					}
				}
			}
		}
	}

	// Load average
	if loadData, err := os.ReadFile("/proc/loadavg"); err == nil {
		fields := strings.Fields(string(loadData))
		if len(fields) >= 3 {
			if load1, err := strconv.ParseFloat(fields[0], 64); err == nil {
				stats.Load1Min = load1
			}
			if load5, err := strconv.ParseFloat(fields[1], 64); err == nil {
				stats.Load5Min = load5
			}
			if load15, err := strconv.ParseFloat(fields[2], 64); err == nil {
				stats.Load15Min = load15
			}
		}
	}

	c.JSON(http.StatusOK, APIResponse{
		Status: "success",
		Data:   stats,
	})
}

// GetFiles returns file information
func (api *AdminAPI) GetFiles(c *gin.Context) {
	files := []FileInfo{}

	// HLS files
	hlsDir := "/tmp/hls_shared"
	if entries, err := os.ReadDir(hlsDir); err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				streamPath := filepath.Join(hlsDir, entry.Name())
				if streamFiles, err := os.ReadDir(streamPath); err == nil {
					tsCount := 0
					m3u8Count := 0
					var totalSize int64
					var lastMod time.Time

					for _, file := range streamFiles {
						if info, err := file.Info(); err == nil {
							totalSize += info.Size()
							if info.ModTime().After(lastMod) {
								lastMod = info.ModTime()
							}

							if strings.HasSuffix(file.Name(), ".ts") {
								tsCount++
							} else if strings.HasSuffix(file.Name(), ".m3u8") {
								m3u8Count++
							}
						}
					}

					if tsCount > 0 || m3u8Count > 0 {
						files = append(files, FileInfo{
							Path:         streamPath,
							Type:         "hls",
							StreamName:   entry.Name(),
							FileCount:    len(streamFiles),
							TSCount:      tsCount,
							M3U8Count:    m3u8Count,
							TotalSize:    totalSize,
							LastModified: lastMod.Format(time.RFC3339),
						})
					}
				}
			}
		}
	}

	c.JSON(http.StatusOK, APIResponse{
		Status: "success",
		Data: FilesData{
			Files:     files,
			Timestamp: time.Now().Format(time.RFC3339),
		},
	})
}

// Helper functions
func (api *AdminAPI) getDirUsage(dir string) (string, error) {
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		return "0B", nil
	}

	cmd := exec.Command("du", "-sh", dir)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	fields := strings.Fields(string(output))
	if len(fields) > 0 {
		return fields[0], nil
	}
	return "0B", nil
}

func (api *AdminAPI) getDiskInfo(dir string) (string, error) {
	cmd := exec.Command("df", "-h", dir)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	lines := strings.Split(string(output), "\n")
	if len(lines) > 1 {
		return lines[1], nil
	}
	return "", fmt.Errorf("no disk info found")
}

func (api *AdminAPI) controlStream(streamName, action string) APIResponse {
	switch action {
	case "stop":
		cmd := exec.Command("curl", "-s", fmt.Sprintf("http://localhost:8080/control/drop/publisher?app=live&name=%s", streamName))
		output, err := cmd.Output()
		if err != nil {
			return APIResponse{
				Status: "error",
				Error:  fmt.Sprintf("Failed to stop stream %s: %s", streamName, err.Error()),
			}
		}
		
		return APIResponse{
			Status:  "success",
			Message: fmt.Sprintf("Stream %s stopped successfully", streamName),
			Data: map[string]string{
				"action": action,
				"stream": streamName,
				"output": string(output),
			},
		}

	case "start":
		return APIResponse{
			Status:  "info",
			Message: fmt.Sprintf("Stream %s ready for RTMP publishing", streamName),
			Data: map[string]string{
				"action":   action,
				"stream":   streamName,
				"rtmp_url": fmt.Sprintf("rtmp://localhost:1935/live/%s", streamName),
			},
		}

	case "restart":
		// Stop first
		api.controlStream(streamName, "stop")
		time.Sleep(1 * time.Second)
		
		return APIResponse{
			Status:  "success",
			Message: fmt.Sprintf("Stream %s restarted. Ready for new RTMP connection.", streamName),
			Data: map[string]string{
				"action":   action,
				"stream":   streamName,
				"rtmp_url": fmt.Sprintf("rtmp://localhost:1935/live/%s", streamName),
			},
		}

	default:
		return APIResponse{
			Status: "error",
			Error:  fmt.Sprintf("Unknown action: %s", action),
		}
	}
}

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

func main() {
	port := "9000"
	if envPort := os.Getenv("PORT"); envPort != "" {
		port = envPort
	}

	// Set Gin to production mode for better performance
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(CORSMiddleware())

	// Create admin API
	adminAPI := NewAdminAPI()
	adminAPI.SetupRoutes(r)

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"service":   "admin-api",
			"timestamp": time.Now().UTC(),
			"version":   "2.0.0-go",
		})
	})

	log.Printf("🚀 StreamForge Admin API (Go) starting on 0.0.0.0:%s", port)
	log.Printf("⚡ Performance optimized - Python eliminated!")
	
	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}