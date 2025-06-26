package database

import (
	"fmt"
	"os"
	"time"

	"gorm.io/driver/sqlite"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
	"github.com/streamforge/platform/pkg/models"
	"gorm.io/gorm"
	glogger "gorm.io/gorm/logger"
)

// Database represents the database connection
type Database struct {
	db *gorm.DB
}

// NewDatabase creates a new database connection
func NewDatabase(cfg *config.Config) (*Database, error) {
	var db *gorm.DB
	var err error

	// Configure GORM logger
	gormLogger := glogger.Default
	if cfg.Logger.Level == "debug" {
		gormLogger = glogger.Default.LogMode(glogger.Info)
	} else {
		gormLogger = glogger.Default.LogMode(glogger.Silent)
	}

	// Use file-based SQLite database (CGO-free driver)
	// Ensure data directory exists
	if err := CreateDataDirectory(); err != nil {
		return nil, err
	}
	dbPath := "./data/streamforge.db"
	logger.Info("Connecting to SQLite database at", dbPath)
	db, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		Logger: gormLogger,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Configure connection pool
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get database instance: %w", err)
	}

	// Configure SQLite connection settings
	sqlDB.SetMaxOpenConns(1)
	sqlDB.SetMaxIdleConns(1)
	sqlDB.SetConnMaxLifetime(time.Hour)

	logger.Info("Connected to SQLite database")

	database := &Database{db: db}

	// Auto-migrate the schema
	if err := database.AutoMigrate(); err != nil {
		return nil, fmt.Errorf("failed to migrate database: %w", err)
	}

	return database, nil
}

// AutoMigrate runs database migrations
func (d *Database) AutoMigrate() error {
	logger.Info("Running database migrations...")

	err := d.db.AutoMigrate(
		&models.User{},
		&models.Stream{},
		&models.StreamSession{},
		&models.Viewer{},
		&models.StreamAnalytics{},
		&models.Notification{},
	)

	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	logger.Info("Database migrations completed successfully")
	return nil
}

// GetDB returns the GORM database instance
func (d *Database) GetDB() *gorm.DB {
	return d.db
}

// Close closes the database connection
func (d *Database) Close() error {
	sqlDB, err := d.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// Health checks database connectivity
func (d *Database) Health() error {
	sqlDB, err := d.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Ping()
}

// Transaction executes a function within a database transaction
func (d *Database) Transaction(fn func(*gorm.DB) error) error {
	return d.db.Transaction(fn)
}

// Seed populates the database with initial data
func (d *Database) Seed() error {
	logger.Info("Seeding database with initial data...")

	// Check if users already exist
	var userCount int64
	d.db.Model(&models.User{}).Count(&userCount)

	if userCount > 0 {
		logger.Info("Database already has data, skipping seed")
		return nil
	}

	// Create sample users
	users := []models.User{
		{
			Username:  "demo_user",
			Email:     "demo@streamforge.com",
			Password:  "$2a$10$example.hash.here", // In real app, use proper bcrypt
			FirstName: "Demo",
			LastName:  "User",
			IsActive:  true,
		},
		{
			Username:  "streamer1",
			Email:     "streamer1@streamforge.com",
			Password:  "$2a$10$example.hash.here",
			FirstName: "John",
			LastName:  "Streamer",
			IsActive:  true,
		},
		{
			Username:  "viewer1",
			Email:     "viewer1@streamforge.com",
			Password:  "$2a$10$example.hash.here",
			FirstName: "Jane",
			LastName:  "Viewer",
			IsActive:  true,
		},
	}

	for _, user := range users {
		if err := d.db.Create(&user).Error; err != nil {
			return fmt.Errorf("failed to create user %s: %w", user.Username, err)
		}
	}

	// Create sample stream for demo user
	var demoUser models.User
	if err := d.db.Where("username = ?", "demo_user").First(&demoUser).Error; err != nil {
		return fmt.Errorf("failed to find demo user: %w", err)
	}

	demoStream := models.Stream{
		UserID:      demoUser.ID,
		Title:       "Demo Live Stream",
		Description: "A demonstration live stream for testing purposes",
		StreamKey:   "demo-stream-key-123",
		Status:      models.StreamStatusOffline,
	}

	if err := d.db.Create(&demoStream).Error; err != nil {
		return fmt.Errorf("failed to create demo stream: %w", err)
	}

	logger.Info("Database seeded successfully")
	return nil
}

// CreateDataDirectory creates the data directory if it doesn't exist
func CreateDataDirectory() error {
	const dataDir = "./data"

	// Create data directory for SQLite database
	if err := createDirIfNotExists(dataDir); err != nil {
		return fmt.Errorf("failed to create data directory: %w", err)
	}

	return nil
}

// createDirIfNotExists creates a directory if it doesn't exist
func createDirIfNotExists(dir string) error {
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
		logger.Info("Created directory:", dir)
	}
	return nil
}
