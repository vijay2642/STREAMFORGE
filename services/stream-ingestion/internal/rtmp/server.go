package rtmp

import (
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
)

// Server represents an RTMP server
type Server struct {
	config    *config.Config
	listener  net.Listener
	streams   map[string]*Stream
	streamsMu sync.RWMutex
	running   bool
}

// Stream represents an active RTMP stream
type Stream struct {
	Key       string
	Publisher *Client
	Viewers   map[string]*Client
	viewersMu sync.RWMutex
	StartTime time.Time
	Stats     StreamStats
}

// Client represents an RTMP client connection
type Client struct {
	Conn      net.Conn
	StreamKey string
	Type      ClientType
	StartTime time.Time
}

// ClientType represents the type of RTMP client
type ClientType int

const (
	ClientTypePublisher ClientType = iota
	ClientTypeViewer
)

// StreamStats holds statistics for a stream
type StreamStats struct {
	ViewerCount int
	BytesIn     int64
	BytesOut    int64
	Duration    time.Duration
}

// NewServer creates a new RTMP server
func NewServer(cfg *config.Config) *Server {
	return &Server{
		config:  cfg,
		streams: make(map[string]*Stream),
		running: false,
	}
}

// Start starts the RTMP server
func (s *Server) Start() error {
	addr := fmt.Sprintf(":%d", s.config.Stream.RTMPPort)

	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("failed to listen on %s: %w", addr, err)
	}

	s.listener = listener
	s.running = true

	logger.Info("RTMP server started on", addr)

	for s.running {
		conn, err := listener.Accept()
		if err != nil {
			if s.running {
				logger.Error("Error accepting connection:", err)
			}
			continue
		}

		go s.handleConnection(conn)
	}

	return nil
}

// Stop stops the RTMP server
func (s *Server) Stop() {
	s.running = false

	if s.listener != nil {
		s.listener.Close()
	}

	// Close all streams
	s.streamsMu.Lock()
	for _, stream := range s.streams {
		s.closeStream(stream)
	}
	s.streams = make(map[string]*Stream)
	s.streamsMu.Unlock()

	logger.Info("RTMP server stopped")
}

// handleConnection handles a new RTMP connection
func (s *Server) handleConnection(conn net.Conn) {
	defer conn.Close()

	logger.Info("New RTMP connection from", conn.RemoteAddr())

	// Perform RTMP handshake
	if err := PerformHandshake(conn); err != nil {
		logger.Error("RTMP handshake failed:", err)
		return
	}

	logger.Info("RTMP handshake completed successfully")

	// Read RTMP chunks to get stream key
	var streamKey string
	for i := 0; i < 10; i++ { // Limit attempts to avoid infinite loop
		chunk, err := ReadChunk(conn)
		if err != nil {
			logger.Error("Failed to read RTMP chunk:", err)
			return
		}

		// Try to extract stream key from chunk data
		if len(chunk.Data) > 0 {
			key := ExtractStreamKey(chunk.Data)
			if key != "default-stream" {
				streamKey = key
				break
			}
		}
	}

	if streamKey == "" {
		streamKey = "default-stream"
	}

	logger.Info("Extracted stream key:", streamKey)

	// Send success response
	if err := WriteResponse(conn, true); err != nil {
		logger.Error("Failed to send RTMP response:", err)
		return
	}

	client := &Client{
		Conn:      conn,
		StreamKey: streamKey,
		Type:      ClientTypePublisher,
		StartTime: time.Now(),
	}

	s.handlePublisher(client)
}

// handlePublisher handles a publishing client
func (s *Server) handlePublisher(client *Client) {
	streamKey := client.StreamKey

	s.streamsMu.Lock()
	stream, exists := s.streams[streamKey]
	if !exists {
		stream = &Stream{
			Key:       streamKey,
			Viewers:   make(map[string]*Client),
			StartTime: time.Now(),
		}
		s.streams[streamKey] = stream
	}

	if stream.Publisher != nil {
		// Stream already has a publisher
		s.streamsMu.Unlock()
		logger.Warn("Stream", streamKey, "already has a publisher")
		return
	}

	stream.Publisher = client
	s.streamsMu.Unlock()

	logger.Info("Publisher started stream:", streamKey)

	// Handle stream data (simplified)
	buffer := make([]byte, 4096)
	for {
		n, err := client.Conn.Read(buffer)
		if err != nil {
			break
		}

		// Update stats
		stream.Stats.BytesIn += int64(n)

		// Broadcast to viewers (simplified)
		s.broadcastToViewers(stream, buffer[:n])
	}

	// Clean up
	s.streamsMu.Lock()
	if stream.Publisher == client {
		stream.Publisher = nil
	}
	if stream.Publisher == nil && len(stream.Viewers) == 0 {
		delete(s.streams, streamKey)
	}
	s.streamsMu.Unlock()

	logger.Info("Publisher disconnected from stream:", streamKey)
}

// broadcastToViewers broadcasts data to all viewers of a stream
func (s *Server) broadcastToViewers(stream *Stream, data []byte) {
	stream.viewersMu.RLock()
	defer stream.viewersMu.RUnlock()

	for _, viewer := range stream.Viewers {
		go func(v *Client) {
			_, err := v.Conn.Write(data)
			if err != nil {
				// Remove viewer on error
				stream.viewersMu.Lock()
				delete(stream.Viewers, v.Conn.RemoteAddr().String())
				stream.viewersMu.Unlock()
				v.Conn.Close()
			}
		}(viewer)
	}

	stream.Stats.BytesOut += int64(len(data)) * int64(len(stream.Viewers))
}

// closeStream closes a stream and all its connections
func (s *Server) closeStream(stream *Stream) {
	if stream.Publisher != nil {
		stream.Publisher.Conn.Close()
	}

	stream.viewersMu.Lock()
	for _, viewer := range stream.Viewers {
		viewer.Conn.Close()
	}
	stream.viewersMu.Unlock()
}

// GetActiveStreams returns all active streams
func (s *Server) GetActiveStreams() map[string]*Stream {
	s.streamsMu.RLock()
	defer s.streamsMu.RUnlock()

	result := make(map[string]*Stream)
	for key, stream := range s.streams {
		result[key] = stream
	}

	return result
}

// GetStream returns a specific stream
func (s *Server) GetStream(streamKey string) (*Stream, bool) {
	s.streamsMu.RLock()
	defer s.streamsMu.RUnlock()

	stream, exists := s.streams[streamKey]
	return stream, exists
}

// GetStreamStats returns statistics for a stream
func (s *Stream) GetStats() StreamStats {
	s.viewersMu.RLock()
	defer s.viewersMu.RUnlock()

	stats := s.Stats
	stats.ViewerCount = len(s.Viewers)
	stats.Duration = time.Since(s.StartTime)

	return stats
}
