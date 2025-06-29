package transcoder

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

// Quality represents a transcoding quality profile
type Quality struct {
	Name         string
	Resolution   string
	VideoBitrate string
	MaxBitrate   string
	BufSize      string
}

// TranscoderProcess represents an active transcoding process
type TranscoderProcess struct {
	StreamKey string
	Cmd       *exec.Cmd
	StartTime time.Time
	OutputDir string
	Status    string
	// Enhanced fields for better monitoring
	PID       int
	Qualities []Quality
}

// Manager manages multiple transcoding processes
type Manager struct {
	rtmpURL   string
	outputDir string
	processes map[string]*TranscoderProcess
	mutex     sync.RWMutex
	qualities []Quality
}

// NewManager creates a new transcoder manager
func NewManager(rtmpURL, outputDir string) *Manager {
	// Define quality profiles optimized for low-buffering concurrent streaming
	qualities := []Quality{
		{Name: "1080p", Resolution: "1920x1080", VideoBitrate: "3500k", MaxBitrate: "3850k", BufSize: "7000k"},
		{Name: "720p", Resolution: "1280x720", VideoBitrate: "2000k", MaxBitrate: "2200k", BufSize: "4000k"},
		{Name: "480p", Resolution: "854x480", VideoBitrate: "1200k", MaxBitrate: "1320k", BufSize: "2400k"},
		{Name: "360p", Resolution: "640x360", VideoBitrate: "800k", MaxBitrate: "880k", BufSize: "1600k"},
		{Name: "240p", Resolution: "426x240", VideoBitrate: "620k", MaxBitrate: "680k", BufSize: "1240k"},
		{Name: "144p", Resolution: "256x144", VideoBitrate: "400k", MaxBitrate: "440k", BufSize: "800k"},
	}

	return &Manager{
		rtmpURL:   rtmpURL,
		outputDir: outputDir,
		processes: make(map[string]*TranscoderProcess),
		qualities: qualities,
	}
}

// GetQualityProfiles returns the available quality profiles
func (m *Manager) GetQualityProfiles() []Quality {
	return m.qualities
}

// StartTranscoder starts actual Go-based transcoding (replacing shell scripts)
func (m *Manager) StartTranscoder(streamKey string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Check if already running
	if proc, exists := m.processes[streamKey]; exists {
		if proc.Status == "running" {
			return fmt.Errorf("transcoder for %s is already running", streamKey)
		}
	}

	log.Printf("🎬 Starting Go-based transcoding for stream: %s", streamKey)

	// Create output directory structure
	streamOutputDir := filepath.Join(m.outputDir, streamKey)
	if err := os.MkdirAll(streamOutputDir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Initialize HLS manager for this stream
	hlsManager := NewHLSManager(m.outputDir)
	
	// Generate master playlist with proper CODECS
	if err := hlsManager.GenerateMasterPlaylist(streamKey); err != nil {
		return fmt.Errorf("failed to generate master playlist: %w", err)
	}

	// Build FFmpeg command
	inputURL := fmt.Sprintf("%s/%s", m.rtmpURL, streamKey)
	args := hlsManager.GenerateFFmpegCommand(streamKey, inputURL)
	
	// Start FFmpeg process
	cmd := exec.Command("ffmpeg", args...)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start FFmpeg: %w", err)
	}

	// Create process tracking
	process := &TranscoderProcess{
		StreamKey: streamKey,
		Cmd:       cmd,
		StartTime: time.Now(),
		OutputDir: streamOutputDir,
		Status:    "running",
		PID:       cmd.Process.Pid,
		Qualities: m.qualities,
	}

	m.processes[streamKey] = process

	// Start monitoring in background
	go m.monitorProcess(streamKey, hlsManager)

	log.Printf("✅ Go-based transcoding started for %s (PID: %d)", streamKey, cmd.Process.Pid)
	return nil
}

// StopTranscoder stops monitoring for a stream key
func (m *Manager) StopTranscoder(streamKey string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	process, exists := m.processes[streamKey]
	if !exists {
		return fmt.Errorf("no stream monitoring found for stream key: %s", streamKey)
	}

	if process.Status != "monitoring" && process.Status != "running" {
		return fmt.Errorf("stream monitoring for %s is not active", streamKey)
	}

	log.Printf("🛑 Stopping stream monitoring for: %s", streamKey)
	log.Printf("ℹ️  Note: NGINX-managed transcoding process will continue until stream ends")

	process.Status = "stopped"
	delete(m.processes, streamKey)

	log.Printf("✅ Stream monitoring stopped for %s", streamKey)
	return nil
}

// GetStatus returns the status of a transcoder
func (m *Manager) GetStatus(streamKey string) (*TranscoderProcess, bool) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	process, exists := m.processes[streamKey]
	return process, exists
}

// GetActiveTranscoders returns all active monitoring processes
func (m *Manager) GetActiveTranscoders() map[string]*TranscoderProcess {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	active := make(map[string]*TranscoderProcess)
	for key, process := range m.processes {
		if process.Status == "monitoring" || process.Status == "running" {
			active[key] = process
		}
	}
	return active
}

// StopAll stops all active monitoring
func (m *Manager) StopAll() {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	log.Printf("🛑 Stopping all stream monitoring")
	for streamKey, process := range m.processes {
		if process.Status == "monitoring" || process.Status == "running" {
			log.Printf("Stopping monitoring for %s", streamKey)
			process.Status = "stopped"
		}
	}
	m.processes = make(map[string]*TranscoderProcess)
	log.Printf("ℹ️  Note: NGINX-managed transcoding processes will continue until streams end")
}

// monitorProcess monitors Go-managed FFmpeg process and HLS health
func (m *Manager) monitorProcess(streamKey string, hlsManager *HLSManager) {
	log.Printf("📊 Starting Go process monitoring for %s", streamKey)

	for {
		m.mutex.RLock()
		process, exists := m.processes[streamKey]
		m.mutex.RUnlock()

		if !exists || process.Status == "stopped" {
			break
		}

		// Check if FFmpeg process is still running
		if process.Cmd != nil && process.Cmd.Process != nil {
			if proc, err := os.FindProcess(process.Cmd.Process.Pid); err != nil || proc == nil {
				m.mutex.Lock()
				if p, exists := m.processes[streamKey]; exists {
					p.Status = "failed"
					log.Printf("❌ FFmpeg process for %s has died", streamKey)
				}
				m.mutex.Unlock()
				break
			}
		}

		// Check HLS health using Go HLS manager
		if stats, err := hlsManager.MonitorHLSHealth(streamKey); err == nil {
			m.mutex.Lock()
			if process, exists := m.processes[streamKey]; exists {
				if stats.Active {
					process.Status = "running"
				} else {
					process.Status = "stale"
					log.Printf("⚠️  HLS output for %s appears stale", streamKey)
				}
			}
			m.mutex.Unlock()
		}

		time.Sleep(10 * time.Second)
	}

	log.Printf("📊 Go process monitoring stopped for %s", streamKey)
}

// getProfile returns the H.264 profile for a quality level
func (m *Manager) getProfile(index int) string {
	if index <= 2 { // 1080p, 720p, 480p
		return "main"
	}
	return "baseline" // 360p, 240p, 144p
}

// getLevel returns the H.264 level for a quality level
func (m *Manager) getLevel(index int) string {
	switch index {
	case 0: // 1080p
		return "4.0"
	case 1: // 720p
		return "3.1"
	default:
		return "3.0"
	}
}

// getAudioBitrate returns the audio bitrate for a quality level
func (m *Manager) getAudioBitrate(index int) string {
	if index <= 2 { // 1080p, 720p, 480p
		return "128k"
	}
	return "96k" // Lower quality levels
}
