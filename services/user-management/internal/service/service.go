package service

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/models"
	"github.com/streamforge/platform/services/user-management/internal/repository"
	"golang.org/x/crypto/bcrypt"
)

type UserService struct {
	config *config.Config
	repo   *repository.UserRepository
}

func NewUserService(cfg *config.Config, repo *repository.UserRepository) *UserService {
	return &UserService{
		config: cfg,
		repo:   repo,
	}
}

func (s *UserService) CreateUser(username, email, password string) (*models.User, error) {
	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := &models.User{
		Username: username,
		Email:    email,
		Password: string(hashedPassword),
	}

	return s.repo.Create(user)
}

func (s *UserService) AuthenticateUser(email, password string) (string, error) {
	user, err := s.repo.GetByEmail(email)
	if err != nil {
		return "", err
	}

	// Check password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		return "", errors.New("invalid password")
	}

	// Generate JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": user.ID,
		"email":   user.Email,
		"exp":     time.Now().Add(time.Duration(s.config.Auth.TokenDuration) * time.Hour).Unix(),
	})

	tokenString, err := token.SignedString([]byte(s.config.Auth.JWTSecret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func (s *UserService) GetUserByID(id uint) (*models.User, error) {
	return s.repo.GetByID(id)
}

func (s *UserService) UpdateUser(id uint, username, email string) (*models.User, error) {
	user, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}

	if username != "" {
		user.Username = username
	}
	if email != "" {
		user.Email = email
	}

	return s.repo.Update(user)
}

func (s *UserService) DeleteUser(id uint) error {
	return s.repo.Delete(id)
}
