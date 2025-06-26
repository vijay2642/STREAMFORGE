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

// StartTranscoder starts FFmpeg transcoding for a stream key
func (m *Manager) StartTranscoder(streamKey string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Check if already running
	if proc, exists := m.processes[streamKey]; exists {
		if proc.Status == "running" {
			return fmt.Errorf("transcoder for %s is already running", streamKey)
		}
	}

	log.Printf("🎬 Starting transcoder for stream key: %s", streamKey)

	// Create output directory structure
	streamOutputDir := filepath.Join(m.outputDir, streamKey)
	if err := os.MkdirAll(streamOutputDir, 0755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Create subdirectories for each quality (0-5)
	for i := 0; i < len(m.qualities); i++ {
		qualityDir := filepath.Join(streamOutputDir, fmt.Sprintf("%d", i))
		if err := os.MkdirAll(qualityDir, 0755); err != nil {
			return fmt.Errorf("failed to create quality directory %s: %w", qualityDir, err)
		}
	}

	// Build FFmpeg arguments
	inputURL := fmt.Sprintf("%s/%s", m.rtmpURL, streamKey)
	args := m.buildFFmpegArgs(inputURL, streamOutputDir)

	// Start FFmpeg process
	cmd := exec.Command("ffmpeg", args...)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start ffmpeg: %w", err)
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

	// Handle process monitoring in goroutine
	go m.monitorProcess(streamKey, cmd)

	log.Printf("✅ Transcoder started for %s (PID: %d)", streamKey, cmd.Process.Pid)
	return nil
}

// StopTranscoder stops the transcoding process for a stream key
func (m *Manager) StopTranscoder(streamKey string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	process, exists := m.processes[streamKey]
	if !exists {
		return fmt.Errorf("no transcoder found for stream key: %s", streamKey)
	}

	if process.Status != "running" {
		return fmt.Errorf("transcoder for %s is not running", streamKey)
	}

	log.Printf("🛑 Stopping transcoder for stream key: %s", streamKey)

	// Send SIGINT to FFmpeg for graceful shutdown
	if err := process.Cmd.Process.Signal(os.Interrupt); err != nil {
		// If SIGINT fails, force kill
		if killErr := process.Cmd.Process.Kill(); killErr != nil {
			log.Printf("Failed to kill process for %s: %v", streamKey, killErr)
		}
	}

	process.Status = "stopped"
	delete(m.processes, streamKey)

	log.Printf("✅ Transcoder stopped for %s", streamKey)
	return nil
}

// GetStatus returns the status of a transcoder
func (m *Manager) GetStatus(streamKey string) (*TranscoderProcess, bool) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	process, exists := m.processes[streamKey]
	return process, exists
}

// GetActiveTranscoders returns all active transcoding processes
func (m *Manager) GetActiveTranscoders() map[string]*TranscoderProcess {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	active := make(map[string]*TranscoderProcess)
	for key, process := range m.processes {
		if process.Status == "running" {
			active[key] = process
		}
	}
	return active
}

// StopAll stops all active transcoders
func (m *Manager) StopAll() {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	log.Printf("🛑 Stopping all active transcoders")
	for streamKey, process := range m.processes {
		if process.Status == "running" {
			log.Printf("Stopping transcoder for %s", streamKey)
			if err := process.Cmd.Process.Signal(os.Interrupt); err != nil {
				process.Cmd.Process.Kill()
			}
		}
	}
	m.processes = make(map[string]*TranscoderProcess)
}

// buildFFmpegArgs builds simple relay to nginx-rtmp
func (m *Manager) buildFFmpegArgs(inputURL, outputDir string) []string {
	// Simple relay to nginx-rtmp for HLS generation
	args := []string{
		"-y", // overwrite output files
		"-i", inputURL,
		"-c", "copy", // Copy streams without re-encoding
		"-f", "flv", // Output FLV for RTMP
		"rtmp://localhost:1935/live/" + filepath.Base(outputDir), // Send to nginx-rtmp
	}

	return args
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

// monitorProcess monitors an FFmpeg process and handles its lifecycle
func (m *Manager) monitorProcess(streamKey string, cmd *exec.Cmd) {
	// Wait for process completion
	err := cmd.Wait()

	m.mutex.Lock()
	defer m.mutex.Unlock()

	if process, exists := m.processes[streamKey]; exists {
		if err != nil {
			log.Printf("❌ FFmpeg process for %s exited with error: %v", streamKey, err)
			process.Status = "error"
		} else {
			log.Printf("✅ FFmpeg process for %s completed successfully", streamKey)
			process.Status = "completed"
		}

		// Clean up
		delete(m.processes, streamKey)
	}
}
