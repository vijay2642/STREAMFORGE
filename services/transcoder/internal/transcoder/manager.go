package transcoder

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
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

// Manager manages multiple transcoding processes with robust concurrency control
type Manager struct {
	rtmpURL   string
	outputDir string
	lockDir   string
	processes map[string]*TranscoderProcess
	mutex     sync.RWMutex
	qualities []Quality
}

// NewManager creates a new transcoder manager with comprehensive initialization
func NewManager(rtmpURL, outputDir string) *Manager {
	// Define quality profiles with 1080p support
	qualities := []Quality{
		{Name: "1080p", Resolution: "1920x1080", VideoBitrate: "5000k", MaxBitrate: "5500k", BufSize: "5000k"},
		{Name: "720p", Resolution: "1280x720", VideoBitrate: "2800k", MaxBitrate: "3000k", BufSize: "2800k"},
		{Name: "480p", Resolution: "854x480", VideoBitrate: "1400k", MaxBitrate: "1500k", BufSize: "1400k"},
		{Name: "360p", Resolution: "640x360", VideoBitrate: "800k", MaxBitrate: "900k", BufSize: "800k"},
	}

	// Create lock directory with proper permissions
	lockDir := "/tmp/streamforge_locks"
	if err := os.MkdirAll(lockDir, 0755); err != nil {
		log.Printf("⚠️  Failed to create lock directory: %v", err)
	}

	// Create output directory with proper permissions
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		log.Printf("⚠️  Failed to create output directory: %v", err)
	}

	manager := &Manager{
		rtmpURL:   rtmpURL,
		outputDir: outputDir,
		lockDir:   lockDir,
		processes: make(map[string]*TranscoderProcess),
		qualities: qualities,
	}

	// Clean up any orphaned processes and lock files from previous runs
	if err := manager.cleanupOrphanedProcesses(); err != nil {
		log.Printf("⚠️  Failed to cleanup orphaned processes: %v", err)
	}

	log.Printf("🎬 Transcoder Manager initialized with %d quality profiles", len(qualities))
	log.Printf("📁 Output directory: %s", outputDir)
	log.Printf("🔒 Lock directory: %s", lockDir)

	return manager
}

// GetQualityProfiles returns the available quality profiles
func (m *Manager) GetQualityProfiles() []Quality {
	return m.qualities
}

// acquireStreamLock attempts to acquire a file-based lock for the stream using atomic operations
func (m *Manager) acquireStreamLock(streamKey string) error {
	lockFile := filepath.Join(m.lockDir, fmt.Sprintf("%s.lock", streamKey))
	tempLockFile := lockFile + ".tmp"
	currentPID := os.Getpid()

	// Use atomic file operations to prevent TOCTOU race conditions
	for attempts := 0; attempts < 3; attempts++ {
		// Try to create temporary lock file atomically
		file, err := os.OpenFile(tempLockFile, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
		if err != nil {
			if os.IsExist(err) {
				time.Sleep(time.Duration(attempts*100) * time.Millisecond)
				continue
			}
			return fmt.Errorf("failed to create temp lock file: %w", err)
		}

		// Write our PID to temp file
		_, writeErr := file.WriteString(fmt.Sprintf("%d\n%d", currentPID, time.Now().Unix()))
		file.Close()

		if writeErr != nil {
			os.Remove(tempLockFile)
			return fmt.Errorf("failed to write to temp lock file: %w", writeErr)
		}

		// Check if target lock file exists and validate it
		if data, err := ioutil.ReadFile(lockFile); err == nil {
			lines := strings.Split(strings.TrimSpace(string(data)), "\n")
			if len(lines) >= 1 {
				if pid, err := strconv.Atoi(lines[0]); err == nil {
					if isProcessRunning(pid) {
						os.Remove(tempLockFile)
						return fmt.Errorf("stream %s is locked by running process PID %d", streamKey, pid)
					}
				}
			}
			// Stale lock detected, remove it
			os.Remove(lockFile)
		}

		// Atomically move temp file to final lock file
		if err := os.Rename(tempLockFile, lockFile); err != nil {
			os.Remove(tempLockFile)
			if attempts == 2 {
				return fmt.Errorf("failed to acquire lock after retries: %w", err)
			}
			time.Sleep(time.Duration(attempts*100) * time.Millisecond)
			continue
		}

		return nil
	}

	return fmt.Errorf("failed to acquire lock for stream %s after 3 attempts", streamKey)
}

// releaseStreamLock releases the file-based lock for the stream
func (m *Manager) releaseStreamLock(streamKey string) {
	lockFile := filepath.Join(m.lockDir, fmt.Sprintf("%s.lock", streamKey))
	os.Remove(lockFile)
}

// isProcessRunning checks if a process with given PID is running
func isProcessRunning(pid int) bool {
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}

	// Send signal 0 to check if process exists
	err = process.Signal(syscall.Signal(0))
	return err == nil
}

// checkExistingFFmpegProcesses checks for existing FFmpeg processes for this stream with enhanced detection
func (m *Manager) checkExistingFFmpegProcesses(streamKey string) error {
	// Read /proc to find FFmpeg processes
	procDirs, err := os.ReadDir("/proc")
	if err != nil {
		log.Printf("⚠️  Cannot read /proc directory: %v", err)
		return nil // Can't check, proceed with caution
	}

	for _, procDir := range procDirs {
		if !procDir.IsDir() {
			continue
		}

		// Check if directory name is a PID
		pidStr := procDir.Name()
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue
		}
		if pid <= 0 {
			continue
		}

		// Read command line arguments
		cmdlineFile := filepath.Join("/proc", pidStr, "cmdline")
		if cmdline, err := os.ReadFile(cmdlineFile); err == nil {
			// cmdline is null-separated, convert to space-separated for easier parsing
			cmdStr := strings.ReplaceAll(string(cmdline), "\x00", " ")

			// Enhanced detection: check for FFmpeg and our specific stream
			if strings.Contains(cmdStr, "ffmpeg") &&
				(strings.Contains(cmdStr, streamKey) ||
					strings.Contains(cmdStr, fmt.Sprintf("/%s/", streamKey)) ||
					strings.Contains(cmdStr, fmt.Sprintf("=%s", streamKey))) {

				// Double-check the process is actually running
				if isProcessRunning(pid) {
					return fmt.Errorf("existing FFmpeg process found for stream %s (PID: %s, cmd: %.100s...)",
						streamKey, pidStr, cmdStr)
				}
			}
		}
	}

	return nil
}

// cleanupOrphanedProcesses removes stale lock files and kills orphaned FFmpeg processes
func (m *Manager) cleanupOrphanedProcesses() error {
	lockFiles, err := filepath.Glob(filepath.Join(m.lockDir, "*.lock"))
	if err != nil {
		return fmt.Errorf("failed to list lock files: %w", err)
	}

	cleaned := 0
	for _, lockFile := range lockFiles {
		if data, err := os.ReadFile(lockFile); err == nil {
			lines := strings.Split(strings.TrimSpace(string(data)), "\n")
			if len(lines) >= 1 {
				if pid, err := strconv.Atoi(lines[0]); err == nil {
					if !isProcessRunning(pid) {
						// Stale lock file, remove it
						if err := os.Remove(lockFile); err == nil {
							cleaned++
							log.Printf("🧹 Removed stale lock file: %s (PID: %d)", lockFile, pid)
						}
					}
				}
			}
		}
	}

	if cleaned > 0 {
		log.Printf("🧹 Cleaned up %d orphaned lock files", cleaned)
	}

	return nil
}

// StartTranscoder starts actual Go-based transcoding with comprehensive race condition prevention
func (m *Manager) StartTranscoder(streamKey string) error {
	// Input validation
	if streamKey == "" {
		return fmt.Errorf("stream key cannot be empty")
	}
	if len(streamKey) > 64 {
		return fmt.Errorf("stream key too long (max 64 characters)")
	}

	m.mutex.Lock()
	defer m.mutex.Unlock()

	// First check: Verify not already running in our process map
	if proc, exists := m.processes[streamKey]; exists {
		if proc.Status == "running" || proc.Status == "starting" {
			return fmt.Errorf("transcoder for %s is already %s", streamKey, proc.Status)
		}
		// Clean up stale entry
		delete(m.processes, streamKey)
	}

	// Acquire file-based lock to prevent race conditions across service instances
	if err := m.acquireStreamLock(streamKey); err != nil {
		return fmt.Errorf("failed to acquire lock: %w", err)
	}

	// Ensure lock is released on any error
	defer func() {
		if r := recover(); r != nil {
			m.releaseStreamLock(streamKey)
			panic(r)
		}
	}()

	// Check for existing FFmpeg processes system-wide (after acquiring lock)
	if err := m.checkExistingFFmpegProcesses(streamKey); err != nil {
		m.releaseStreamLock(streamKey)
		return fmt.Errorf("existing process detected: %w", err)
	}

	// Mark as starting to prevent concurrent starts
	m.processes[streamKey] = &TranscoderProcess{
		StreamKey: streamKey,
		StartTime: time.Now(),
		Status:    "starting",
	}

	log.Printf("🎬 Starting Go-based transcoding for stream: %s", streamKey)

	// Create output directory structure
	streamOutputDir := filepath.Join(m.outputDir, streamKey)
	if err := os.MkdirAll(streamOutputDir, 0755); err != nil {
		m.releaseStreamLock(streamKey)
		delete(m.processes, streamKey)
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Initialize HLS manager for this stream
	hlsManager := NewHLSManager(m.outputDir)

	// Generate master playlist with proper CODECS
	if err := hlsManager.GenerateMasterPlaylist(streamKey); err != nil {
		m.releaseStreamLock(streamKey)
		delete(m.processes, streamKey)
		return fmt.Errorf("failed to generate master playlist: %w", err)
	}

	// Build FFmpeg command
	inputURL := fmt.Sprintf("%s/%s", m.rtmpURL, streamKey)
	args := hlsManager.GenerateFFmpegCommand(streamKey, inputURL)

	// Start FFmpeg process with timeout protection
	cmd := exec.Command("ffmpeg", args...)

	// Set up process attributes for better management
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true, // Create new process group for clean termination
	}

	if err := cmd.Start(); err != nil {
		m.releaseStreamLock(streamKey)
		delete(m.processes, streamKey)
		return fmt.Errorf("failed to start FFmpeg: %w", err)
	}

	// Verify process actually started
	if cmd.Process == nil {
		m.releaseStreamLock(streamKey)
		delete(m.processes, streamKey)
		return fmt.Errorf("FFmpeg process failed to initialize properly")
	}

	// Update process tracking with running state
	process := m.processes[streamKey]
	process.Cmd = cmd
	process.StartTime = time.Now()
	process.OutputDir = streamOutputDir
	process.Status = "running"
	process.PID = cmd.Process.Pid
	process.Qualities = m.qualities

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

	// Terminate FFmpeg process if it's running
	if process.Cmd != nil && process.Cmd.Process != nil {
		process.Cmd.Process.Signal(syscall.SIGTERM)
		log.Printf("Sent SIGTERM to FFmpeg process PID %d", process.Cmd.Process.Pid)
	}

	process.Status = "stopped"
	delete(m.processes, streamKey)

	// Release the lock
	m.releaseStreamLock(streamKey)

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

// monitorProcess monitors Go-managed FFmpeg process and HLS health with proper synchronization
func (m *Manager) monitorProcess(streamKey string, hlsManager *HLSManager) {
	log.Printf("📊 Starting Go process monitoring for %s", streamKey)
	defer func() {
		// Ensure cleanup on exit
		m.mutex.Lock()
		if process, exists := m.processes[streamKey]; exists && process.Status != "stopped" {
			process.Status = "failed"
			log.Printf("🧹 Cleaning up monitoring for %s", streamKey)
		}
		m.releaseStreamLock(streamKey)
		m.mutex.Unlock()
		log.Printf("📊 Go process monitoring stopped for %s", streamKey)
	}()

	for {
		// Safely get process info with proper locking
		m.mutex.RLock()
		process, exists := m.processes[streamKey]
		if !exists {
			m.mutex.RUnlock()
			break
		}

		// Copy critical fields while holding read lock
		status := process.Status
		var cmd *exec.Cmd
		var pid int
		if process.Cmd != nil {
			cmd = process.Cmd
			if process.Cmd.Process != nil {
				pid = process.Cmd.Process.Pid
			}
		}
		m.mutex.RUnlock()

		if status == "stopped" {
			break
		}

		// Check if FFmpeg process is still running (outside of lock)
		processAlive := false
		if cmd != nil && pid > 0 {
			if proc, err := os.FindProcess(pid); err == nil && proc != nil {
				// Send signal 0 to check if process exists
				if err := proc.Signal(syscall.Signal(0)); err == nil {
					processAlive = true
				}
			}
		}

		// Update process status based on health checks
		m.mutex.Lock()
		if process, exists := m.processes[streamKey]; exists {
			if !processAlive && process.Status == "running" {
				process.Status = "failed"
				log.Printf("❌ FFmpeg process for %s has died (PID: %d)", streamKey, pid)
				m.mutex.Unlock()
				break
			}

			// Check HLS health using Go HLS manager
			if stats, err := hlsManager.MonitorHLSHealth(streamKey); err == nil {
				if stats.Active && processAlive {
					process.Status = "running"
				} else if !stats.Active && processAlive {
					process.Status = "stale"
					log.Printf("⚠️  HLS output for %s appears stale", streamKey)
				}
			}
		}
		m.mutex.Unlock()

		time.Sleep(10 * time.Second)
	}
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
