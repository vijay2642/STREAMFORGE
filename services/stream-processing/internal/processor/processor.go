package processor

import (
	"fmt"
	"os/exec"
	"sync"
	"time"

	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
)

// Processor handles stream processing tasks
type Processor struct {
	config    *config.Config
	processes map[string]*ProcessJob
	mutex     sync.RWMutex
	running   bool
}

// ProcessJob represents a processing job
type ProcessJob struct {
	StreamKey     string
	InputURL      string
	OutputFormats []OutputFormat
	Status        JobStatus
	StartTime     time.Time
	EndTime       *time.Time
	Command       *exec.Cmd
	Stats         ProcessStats
}

// OutputFormat defines an output format for transcoding
type OutputFormat struct {
	Name       string `json:"name"`
	Resolution string `json:"resolution"`
	Bitrate    int    `json:"bitrate"`
	Codec      string `json:"codec"`
	Format     string `json:"format"`
}

// JobStatus represents the status of a processing job
type JobStatus string

const (
	JobStatusPending    JobStatus = "pending"
	JobStatusProcessing JobStatus = "processing"
	JobStatusCompleted  JobStatus = "completed"
	JobStatusFailed     JobStatus = "failed"
	JobStatusCancelled  JobStatus = "cancelled"
)

// ProcessStats holds processing statistics
type ProcessStats struct {
	FramesProcessed int64
	BytesProcessed  int64
	Duration        time.Duration
	FPS             float64
}

// NewProcessor creates a new processor instance
func NewProcessor(cfg *config.Config) *Processor {
	return &Processor{
		config:    cfg,
		processes: make(map[string]*ProcessJob),
		running:   false,
	}
}

// Start starts the processor
func (p *Processor) Start() error {
	p.running = true
	logger.Info("Stream processor started")

	// Start background worker for monitoring jobs
	go p.monitorJobs()

	return nil
}

// Stop stops the processor
func (p *Processor) Stop() {
	p.running = false

	// Stop all running processes
	p.mutex.Lock()
	for _, job := range p.processes {
		if job.Status == JobStatusProcessing && job.Command != nil {
			job.Command.Process.Kill()
			job.Status = JobStatusCancelled
		}
	}
	p.mutex.Unlock()

	logger.Info("Stream processor stopped")
}

// ProcessStream starts processing a stream
func (p *Processor) ProcessStream(streamKey, inputURL string, formats []OutputFormat) error {
	p.mutex.Lock()
	defer p.mutex.Unlock()

	// Check if already processing
	if _, exists := p.processes[streamKey]; exists {
		return fmt.Errorf("stream %s is already being processed", streamKey)
	}

	job := &ProcessJob{
		StreamKey:     streamKey,
		InputURL:      inputURL,
		OutputFormats: formats,
		Status:        JobStatusPending,
		StartTime:     time.Now(),
	}

	p.processes[streamKey] = job

	// Start processing in background
	go p.processJob(job)

	logger.WithField("stream_key", streamKey).Info("Started processing stream")
	return nil
}

// StopProcessing stops processing a stream
func (p *Processor) StopProcessing(streamKey string) error {
	p.mutex.Lock()
	defer p.mutex.Unlock()

	job, exists := p.processes[streamKey]
	if !exists {
		return fmt.Errorf("no processing job found for stream %s", streamKey)
	}

	if job.Status == JobStatusProcessing && job.Command != nil {
		if err := job.Command.Process.Kill(); err != nil {
			logger.Error("Failed to kill process:", err)
		}
		job.Status = JobStatusCancelled
		now := time.Now()
		job.EndTime = &now
	}

	delete(p.processes, streamKey)
	logger.WithField("stream_key", streamKey).Info("Stopped processing stream")
	return nil
}

// GetProcessingStatus returns the status of a processing job
func (p *Processor) GetProcessingStatus(streamKey string) (*ProcessJob, error) {
	p.mutex.RLock()
	defer p.mutex.RUnlock()

	job, exists := p.processes[streamKey]
	if !exists {
		return nil, fmt.Errorf("no processing job found for stream %s", streamKey)
	}

	return job, nil
}

// GetActiveProcesses returns all active processing jobs
func (p *Processor) GetActiveProcesses() map[string]*ProcessJob {
	p.mutex.RLock()
	defer p.mutex.RUnlock()

	result := make(map[string]*ProcessJob)
	for key, job := range p.processes {
		result[key] = job
	}

	return result
}

// processJob processes a single job
func (p *Processor) processJob(job *ProcessJob) {
	job.Status = JobStatusProcessing

	logger.WithField("stream_key", job.StreamKey).Info("Processing job started")

	// Create FFmpeg command for transcoding
	// This is a simplified example - in production you'd want more sophisticated processing
	for _, format := range job.OutputFormats {
		if err := p.transcodeToFormat(job, format); err != nil {
			logger.Error("Transcoding failed:", err)
			job.Status = JobStatusFailed
			now := time.Now()
			job.EndTime = &now
			return
		}
	}

	job.Status = JobStatusCompleted
	now := time.Now()
	job.EndTime = &now

	logger.WithField("stream_key", job.StreamKey).Info("Processing job completed")
}

// transcodeToFormat transcodes stream to a specific format
func (p *Processor) transcodeToFormat(job *ProcessJob, format OutputFormat) error {
	outputPath := fmt.Sprintf("%s/%s_%s.%s",
		p.config.Stream.HLSPath,
		job.StreamKey,
		format.Name,
		format.Format)

	// FFmpeg command for HLS generation
	args := []string{
		"-i", job.InputURL,
		"-c:v", format.Codec,
		"-b:v", fmt.Sprintf("%dk", format.Bitrate),
		"-s", format.Resolution,
		"-f", "hls",
		"-hls_time", fmt.Sprintf("%d", p.config.Stream.SegmentDuration),
		"-hls_list_size", "10",
		"-hls_flags", "delete_segments",
		outputPath,
	}

	cmd := exec.Command("ffmpeg", args...)
	job.Command = cmd

	logger.WithField("stream_key", job.StreamKey).
		WithField("format", format.Name).
		Info("Starting transcoding")

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start ffmpeg: %w", err)
	}

	// Wait for completion
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("ffmpeg failed: %w", err)
	}

	return nil
}

// monitorJobs monitors processing jobs
func (p *Processor) monitorJobs() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for p.running {
		select {
		case <-ticker.C:
			p.cleanupCompletedJobs()
		}
	}
}

// cleanupCompletedJobs removes completed jobs older than 1 hour
func (p *Processor) cleanupCompletedJobs() {
	p.mutex.Lock()
	defer p.mutex.Unlock()

	cutoff := time.Now().Add(-1 * time.Hour)

	for key, job := range p.processes {
		if (job.Status == JobStatusCompleted || job.Status == JobStatusFailed) &&
			job.EndTime != nil && job.EndTime.Before(cutoff) {
			delete(p.processes, key)
			logger.WithField("stream_key", key).Debug("Cleaned up completed job")
		}
	}
}

// GetSupportedFormats returns supported output formats
func (p *Processor) GetSupportedFormats() []OutputFormat {
	return []OutputFormat{
		{
			Name:       "720p",
			Resolution: "1280x720",
			Bitrate:    2500,
			Codec:      "libx264",
			Format:     "m3u8",
		},
		{
			Name:       "480p",
			Resolution: "854x480",
			Bitrate:    1200,
			Codec:      "libx264",
			Format:     "m3u8",
		},
		{
			Name:       "360p",
			Resolution: "640x360",
			Bitrate:    800,
			Codec:      "libx264",
			Format:     "m3u8",
		},
		{
			Name:       "1080p",
			Resolution: "1920x1080",
			Bitrate:    5000,
			Codec:      "libx264",
			Format:     "m3u8",
		},
	}
}
