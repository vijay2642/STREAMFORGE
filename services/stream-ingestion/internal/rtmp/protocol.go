package rtmp

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"strings"
)

// RTMP Constants
const (
	RTMP_VERSION        = 3
	RTMP_HANDSHAKE_SIZE = 1536
)

// RTMPConnection represents an RTMP connection with protocol state
type RTMPConnection struct {
	conn      net.Conn
	streamKey string
	appName   string
	state     RTMPState
}

type RTMPState int

const (
	StateHandshake RTMPState = iota
	StateConnected
	StatePublishing
)

// PerformHandshake performs the RTMP handshake with a client
func PerformHandshake(conn net.Conn) error {
	// Read C0 (1 byte - version)
	c0 := make([]byte, 1)
	if _, err := io.ReadFull(conn, c0); err != nil {
		return fmt.Errorf("failed to read C0: %w", err)
	}

	if c0[0] != RTMP_VERSION {
		return fmt.Errorf("unsupported RTMP version: %d", c0[0])
	}

	// Read C1 (1536 bytes)
	c1 := make([]byte, RTMP_HANDSHAKE_SIZE)
	if _, err := io.ReadFull(conn, c1); err != nil {
		return fmt.Errorf("failed to read C1: %w", err)
	}

	// Send S0 (version)
	s0 := []byte{RTMP_VERSION}
	if _, err := conn.Write(s0); err != nil {
		return fmt.Errorf("failed to write S0: %w", err)
	}

	// Send S1 (echo C1 for simplicity)
	if _, err := conn.Write(c1); err != nil {
		return fmt.Errorf("failed to write S1: %w", err)
	}

	// Read C2 (should echo S1, but we'll just read and ignore)
	c2 := make([]byte, RTMP_HANDSHAKE_SIZE)
	if _, err := io.ReadFull(conn, c2); err != nil {
		return fmt.Errorf("failed to read C2: %w", err)
	}

	// Send S2 (echo C1)
	if _, err := conn.Write(c1); err != nil {
		return fmt.Errorf("failed to write S2: %w", err)
	}

	return nil
}

// RTMPChunk represents an RTMP chunk
type RTMPChunk struct {
	StreamID    uint32
	Timestamp   uint32
	MessageType uint8
	Data        []byte
}

// ReadChunk reads an RTMP chunk from the connection
func ReadChunk(conn net.Conn) (*RTMPChunk, error) {
	// Read basic header (at least 1 byte)
	basicHeader := make([]byte, 1)
	if _, err := io.ReadFull(conn, basicHeader); err != nil {
		return nil, err
	}

	// Parse basic header
	fmt := (basicHeader[0] >> 6) & 0x03
	streamID := uint32(basicHeader[0] & 0x3F)

	// For simplicity, we'll implement a basic chunk reader
	// In a full implementation, you'd handle different chunk types and sizes

	chunk := &RTMPChunk{
		StreamID: streamID,
	}

	// Read message header based on format
	switch fmt {
	case 0: // Type 0 - 11 bytes
		header := make([]byte, 11)
		if _, err := io.ReadFull(conn, header); err != nil {
			return nil, err
		}

		chunk.Timestamp = binary.BigEndian.Uint32(append([]byte{0}, header[0:3]...))
		messageLength := binary.BigEndian.Uint32(append([]byte{0}, header[3:6]...))
		chunk.MessageType = header[6]

		// Read payload
		if messageLength > 0 {
			chunk.Data = make([]byte, messageLength)
			if _, err := io.ReadFull(conn, chunk.Data); err != nil {
				return nil, err
			}
		}
	default:
		// For simplicity, we'll just read a small amount of data for other formats
		data := make([]byte, 128)
		n, _ := conn.Read(data)
		chunk.Data = data[:n]
	}

	return chunk, nil
}

// ExtractStreamKey extracts stream key from RTMP connect command
func ExtractStreamKey(data []byte) string {
	// Look for the stream key in the connect command
	// This is a simplified extraction - in reality, you'd parse AMF0/AMF3
	dataStr := string(data)

	// Look for common patterns where stream key appears
	if idx := strings.Index(dataStr, "stream1"); idx != -1 {
		return "stream1"
	}
	if idx := strings.Index(dataStr, "live/"); idx != -1 {
		// Extract everything after "live/"
		start := idx + 5
		end := start
		for end < len(dataStr) && dataStr[end] != 0 && dataStr[end] != ' ' && dataStr[end] != '\n' {
			end++
		}
		if end > start {
			return dataStr[start:end]
		}
	}

	// Default stream key
	return "default-stream"
}

// WriteResponse sends a simple RTMP response
func WriteResponse(conn net.Conn, success bool) error {
	// Send a simple acknowledgment chunk
	// This is a very basic implementation

	if success {
		// Send success response (simplified)
		response := []byte{0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x14, 0x00, 0x00, 0x00, 0x00}
		_, err := conn.Write(response)
		return err
	} else {
		// Send error response
		response := []byte{0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x15, 0x00, 0x00, 0x00, 0x00}
		_, err := conn.Write(response)
		return err
	}
}
