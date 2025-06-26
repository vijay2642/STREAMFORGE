package repository

import (
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/database"
	"github.com/streamforge/platform/pkg/models"
	"gorm.io/gorm"
)

// UserRepository handles user data operations
type UserRepository struct {
	db *database.Database
}

// NewUserRepository creates a new user repository
func NewUserRepository(cfg *config.Config) (*UserRepository, error) {
	// Create data directory first
	if err := database.CreateDataDirectory(); err != nil {
		return nil, err
	}

	// Initialize database
	db, err := database.NewDatabase(cfg)
	if err != nil {
		return nil, err
	}

	// Seed database with initial data
	if err := db.Seed(); err != nil {
		return nil, fmt.Errorf("failed to seed database: %w", err)
	}

	return &UserRepository{db: db}, nil
}

// Create creates a new user
func (r *UserRepository) Create(user *models.User) (*models.User, error) {
	user.ID = uuid.New()
	if err := r.db.GetDB().Create(user).Error; err != nil {
		return nil, err
	}
	return user, nil
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(id uuid.UUID) (*models.User, error) {
	var user models.User
	err := r.db.GetDB().Where("id = ?", id).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// GetByEmail retrieves a user by email
func (r *UserRepository) GetByEmail(email string) (*models.User, error) {
	var user models.User
	err := r.db.GetDB().Where("email = ?", email).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// Update updates an existing user
func (r *UserRepository) Update(user *models.User) (*models.User, error) {
	if err := r.db.GetDB().Save(user).Error; err != nil {
		return nil, err
	}
	return user, nil
}

// Delete soft deletes a user
func (r *UserRepository) Delete(id uuid.UUID) error {
	return r.db.GetDB().Where("id = ?", id).Delete(&models.User{}).Error
}

// GetUserByUsername retrieves a user by username
func (r *UserRepository) GetUserByUsername(username string) (*models.User, error) {
	var user models.User
	err := r.db.GetDB().Where("username = ?", username).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// ListUsers retrieves users with pagination
func (r *UserRepository) ListUsers(limit, offset int) ([]models.User, int64, error) {
	var users []models.User
	var total int64

	// Get total count
	if err := r.db.GetDB().Model(&models.User{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get paginated users
	if err := r.db.GetDB().Limit(limit).Offset(offset).Find(&users).Error; err != nil {
		return nil, 0, err
	}

	return users, total, nil
}

// UserExists checks if a user exists by email or username
func (r *UserRepository) UserExists(email, username string) (bool, error) {
	var count int64
	err := r.db.GetDB().Model(&models.User{}).
		Where("email = ? OR username = ?", email, username).
		Count(&count).Error

	return count > 0, err
}

// ActivateUser activates a user account
func (r *UserRepository) ActivateUser(id uuid.UUID) error {
	return r.db.GetDB().Model(&models.User{}).
		Where("id = ?", id).
		Update("is_active", true).Error
}

// DeactivateUser deactivates a user account
func (r *UserRepository) DeactivateUser(id uuid.UUID) error {
	return r.db.GetDB().Model(&models.User{}).
		Where("id = ?", id).
		Update("is_active", false).Error
}

// Close closes the database connection
func (r *UserRepository) Close() error {
	return r.db.Close()
}

// Health checks the repository health
func (r *UserRepository) Health() error {
	return r.db.Health()
}
