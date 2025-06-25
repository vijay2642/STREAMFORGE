package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a user in the system
type User struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	Username  string    `json:"username" gorm:"unique;not null"`
	Email     string    `json:"email" gorm:"unique;not null"`
	Password  string    `json:"-" gorm:"not null"`
	FirstName string    `json:"first_name"`
	LastName  string    `json:"last_name"`
	IsActive  bool      `json:"is_active" gorm:"default:true"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Stream represents a live stream
type Stream struct {
	ID          uuid.UUID    `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID      uuid.UUID    `json:"user_id" gorm:"type:uuid;not null"`
	Title       string       `json:"title" gorm:"not null"`
	Description string       `json:"description"`
	StreamKey   string       `json:"stream_key" gorm:"unique;not null"`
	Status      StreamStatus `json:"status" gorm:"default:'offline'"`
	ViewerCount int          `json:"viewer_count" gorm:"default:0"`
	MaxViewers  int          `json:"max_viewers" gorm:"default:0"`
	StartedAt   *time.Time   `json:"started_at"`
	EndedAt     *time.Time   `json:"ended_at"`
	CreatedAt   time.Time    `json:"created_at"`
	UpdatedAt   time.Time    `json:"updated_at"`

	// Relationships
	User User `json:"user" gorm:"foreignKey:UserID"`
}

// StreamSession represents a streaming session
type StreamSession struct {
	ID        uuid.UUID  `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	StreamID  uuid.UUID  `json:"stream_id" gorm:"type:uuid;not null"`
	Quality   string     `json:"quality"`
	Bitrate   int        `json:"bitrate"`
	StartedAt time.Time  `json:"started_at"`
	EndedAt   *time.Time `json:"ended_at"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`

	// Relationships
	Stream Stream `json:"stream" gorm:"foreignKey:StreamID"`
}

// Viewer represents a viewer watching a stream
type Viewer struct {
	ID         uuid.UUID  `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	StreamID   uuid.UUID  `json:"stream_id" gorm:"type:uuid;not null"`
	UserID     *uuid.UUID `json:"user_id" gorm:"type:uuid"` // nullable for anonymous viewers
	IPAddress  string     `json:"ip_address"`
	UserAgent  string     `json:"user_agent"`
	JoinedAt   time.Time  `json:"joined_at"`
	LastSeenAt time.Time  `json:"last_seen_at"`
	WatchTime  int        `json:"watch_time"` // in seconds
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`

	// Relationships
	Stream Stream `json:"stream" gorm:"foreignKey:StreamID"`
	User   *User  `json:"user" gorm:"foreignKey:UserID"`
}

// StreamAnalytics represents analytics data for a stream
type StreamAnalytics struct {
	ID              uuid.UUID `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	StreamID        uuid.UUID `json:"stream_id" gorm:"type:uuid;not null"`
	Date            time.Time `json:"date" gorm:"type:date;not null"`
	TotalViewers    int       `json:"total_viewers"`
	PeakViewers     int       `json:"peak_viewers"`
	AverageViewTime int       `json:"average_view_time"` // in seconds
	TotalWatchTime  int       `json:"total_watch_time"`  // in seconds
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`

	// Relationships
	Stream Stream `json:"stream" gorm:"foreignKey:StreamID"`
}

// Notification represents a notification
type Notification struct {
	ID        uuid.UUID        `json:"id" gorm:"type:uuid;primary_key;default:gen_random_uuid()"`
	UserID    uuid.UUID        `json:"user_id" gorm:"type:uuid;not null"`
	Type      NotificationType `json:"type" gorm:"not null"`
	Title     string           `json:"title" gorm:"not null"`
	Message   string           `json:"message"`
	Data      string           `json:"data"` // JSON data
	IsRead    bool             `json:"is_read" gorm:"default:false"`
	CreatedAt time.Time        `json:"created_at"`
	UpdatedAt time.Time        `json:"updated_at"`

	// Relationships
	User User `json:"user" gorm:"foreignKey:UserID"`
}

// StreamStatus represents the status of a stream
type StreamStatus string

const (
	StreamStatusOffline StreamStatus = "offline"
	StreamStatusOnline  StreamStatus = "online"
	StreamStatusPrivate StreamStatus = "private"
)

// NotificationType represents the type of notification
type NotificationType string

const (
	NotificationTypeStreamStarted NotificationType = "stream_started"
	NotificationTypeStreamEnded   NotificationType = "stream_ended"
	NotificationTypeNewFollower   NotificationType = "new_follower"
	NotificationTypeSystem        NotificationType = "system"
)

// StreamEvent represents real-time stream events
type StreamEvent struct {
	Type      string      `json:"type"`
	StreamID  uuid.UUID   `json:"stream_id"`
	UserID    *uuid.UUID  `json:"user_id,omitempty"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

// StreamEventType constants
const (
	EventStreamStarted      = "stream_started"
	EventStreamEnded        = "stream_ended"
	EventViewerJoined       = "viewer_joined"
	EventViewerLeft         = "viewer_left"
	EventViewerCountUpdated = "viewer_count_updated"
)

// APIResponse represents a standard API response
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// PaginationMeta represents pagination metadata
type PaginationMeta struct {
	Page       int   `json:"page"`
	PerPage    int   `json:"per_page"`
	Total      int64 `json:"total"`
	TotalPages int   `json:"total_pages"`
}

// PaginatedResponse represents a paginated API response
type PaginatedResponse struct {
	APIResponse
	Meta PaginationMeta `json:"meta"`
}
