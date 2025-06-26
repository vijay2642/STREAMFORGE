package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

// StreamConfig represents configuration for a test stream
type StreamConfig struct {
	Name      string
	Frequency int
	Pattern   string
	RTMPURL   string
}

// StreamGenerator manages test stream generation
type StreamGenerator struct {
	streams   map[string]*exec.Cmd
	mutex     sync.RWMutex
	rtmpBase  string
}

// NewStreamGenerator creates a new stream generator
func NewStreamGenerator(rtmpBase string) *StreamGenerator {
	return &StreamGenerator{
		streams:  make(map[string]*exec.Cmd),
		rtmpBase: rtmpBase,
	}
}

// StartStream starts a test stream
func (sg *StreamGenerator) StartStream(config StreamConfig) error {
	sg.mutex.Lock()
	defer sg.mutex.Unlock()

	// Check if stream already exists
	if _, exists := sg.streams[config.Name]; exists {
		return fmt.Errorf("stream %s already running", config.Name)
	}

	rtmpURL := fmt.Sprintf("%s/%s", sg.rtmpBase, config.Name)

	// Build FFmpeg command
	args := []string{
		"-re", // Read input at native frame rate
		"-f", "lavfi", "-i", fmt.Sprintf("%s=size=1920x1080:rate=24", config.Pattern),
		"-f", "lavfi", "-i", fmt.Sprintf("sine=frequency=%d:sample_rate=44100", config.Frequency),
		"-c:v", "libx264",
		"-preset", "veryfast",
		"-profile:v", "high",
		"-level", "4.0",
		"-b:v", "6000k",
		"-maxrate", "6600k",
		"-bufsize", "12000k",
		"-g", "48",
		"-keyint_min", "48",
		"-sc_threshold", "0",
		"-c:a", "aac",
		"-b:a", "128k",
		"-ar", "44100",
		"-f", "flv",
		rtmpURL,
	}

	cmd := exec.Command("ffmpeg", args...)
	
	// Set up logging
	logFile := fmt.Sprintf("/root/STREAMFORGE/logs/stream_%s.log", config.Name)
	logHandle, err := os.Create(logFile)
	if err != nil {
		return fmt.Errorf("failed to create log file: %w", err)
	}
	
	cmd.Stdout = logHandle
	cmd.Stderr = logHandle

	// Start the stream
	if err := cmd.Start(); err != nil {
		logHandle.Close()
		return fmt.Errorf("failed to start stream: %w", err)
	}

	sg.streams[config.Name] = cmd
	
	fmt.Printf("✅ Test stream started: %s (PID: %d)\n", config.Name, cmd.Process.Pid)
	fmt.Printf("📡 RTMP URL: %s\n", rtmpURL)
	fmt.Printf("🎵 Audio frequency: %dHz\n", config.Frequency)
	fmt.Printf("📝 Log: %s\n", logFile)

	// Monitor process in goroutine
	go func() {
		cmd.Wait()
		sg.mutex.Lock()
		delete(sg.streams, config.Name)
		sg.mutex.Unlock()
		logHandle.Close()
		fmt.Printf("⚠️  Stream %s stopped\n", config.Name)
	}()

	return nil
}

// StopStream stops a specific stream
func (sg *StreamGenerator) StopStream(name string) error {
	sg.mutex.Lock()
	defer sg.mutex.Unlock()

	cmd, exists := sg.streams[name]
	if !exists {
		return fmt.Errorf("stream %s not found", name)
	}

	fmt.Printf("🛑 Stopping stream: %s\n", name)
	
	// Send SIGTERM for graceful shutdown
	if err := cmd.Process.Signal(syscall.SIGTERM); err != nil {
		// Force kill if SIGTERM fails
		cmd.Process.Kill()
	}

	delete(sg.streams, name)
	return nil
}

// StopAll stops all streams
func (sg *StreamGenerator) StopAll() {
	sg.mutex.Lock()
	defer sg.mutex.Unlock()

	for name, cmd := range sg.streams {
		fmt.Printf("🛑 Stopping stream: %s\n", name)
		cmd.Process.Signal(syscall.SIGTERM)
	}

	// Wait for all to stop
	for _, cmd := range sg.streams {
		cmd.Wait()
	}

	sg.streams = make(map[string]*exec.Cmd)
}

// GetStatus returns status of all streams
func (sg *StreamGenerator) GetStatus() map[string]bool {
	sg.mutex.RLock()
	defer sg.mutex.RUnlock()

	status := make(map[string]bool)
	for name := range sg.streams {
		status[name] = true
	}
	return status
}

func main() {
	var (
		rtmpURL   = flag.String("rtmp", "rtmp://localhost:1935/live", "RTMP base URL")
		command   = flag.String("cmd", "", "Command: start, stop, status")
		streams   = flag.String("streams", "all", "Streams to operate on (stream1,stream2,stream3 or all)")
		duration  = flag.Duration("duration", 0, "Run duration (0 = infinite)")
	)
	flag.Parse()

	if *command == "" {
		fmt.Println("Usage: streamgen -cmd <start|stop|status> [-streams <stream1,stream2,stream3|all>]")
		fmt.Println("  -rtmp     RTMP base URL (default: rtmp://localhost:1935/live)")
		fmt.Println("  -duration Run duration (default: infinite)")
		os.Exit(1)
	}

	generator := NewStreamGenerator(*rtmpURL)

	// Define test stream configurations
	testStreams := []StreamConfig{
		{Name: "stream1", Frequency: 1000, Pattern: "testsrc2"},
		{Name: "stream2", Frequency: 1200, Pattern: "testsrc"},
		{Name: "stream3", Frequency: 1500, Pattern: "testsrc2"},
	}

	switch *command {
	case "start":
		fmt.Println("🎬 Starting test streams...")
		
		// Parse stream selection
		selectedStreams := testStreams
		if *streams != "all" {
			// TODO: Implement stream filtering
		}

		// Start selected streams
		for _, config := range selectedStreams {
			config.RTMPURL = *rtmpURL + "/" + config.Name
			if err := generator.StartStream(config); err != nil {
				fmt.Printf("❌ Error starting %s: %v\n", config.Name, err)
			}
			time.Sleep(500 * time.Millisecond) // Small delay between starts
		}

		// Handle shutdown signals
		ctx, cancel := context.WithCancel(context.Background())
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

		// Set up duration timer if specified
		if *duration > 0 {
			go func() {
				time.Sleep(*duration)
				fmt.Printf("\n⏱️  Duration %v reached, stopping streams...\n", *duration)
				cancel()
			}()
		}

		// Wait for shutdown
		select {
		case <-sigChan:
			fmt.Println("\n🛑 Shutdown signal received...")
		case <-ctx.Done():
		}

		generator.StopAll()

	case "stop":
		fmt.Println("🛑 Stopping test streams...")
		generator.StopAll()

	case "status":
		status := generator.GetStatus()
		if len(status) == 0 {
			fmt.Println("📭 No active streams")
		} else {
			fmt.Printf("📊 Active streams: %d\n", len(status))
			for name := range status {
				fmt.Printf("  • %s: running\n", name)
			}
		}

	default:
		fmt.Printf("Unknown command: %s\n", *command)
		os.Exit(1)
	}
}