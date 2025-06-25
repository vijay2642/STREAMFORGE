package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/streamforge/platform/pkg/config"
	"github.com/streamforge/platform/pkg/logger"
	"github.com/streamforge/platform/services/user-management/internal/handlers"
	"github.com/streamforge/platform/services/user-management/internal/repository"
	"github.com/streamforge/platform/services/user-management/internal/service"
)

func main() {
	// Load configuration
	cfg, err := config.Load("USER_MANAGEMENT")
	if err != nil {
		log.Fatal("Failed to load configuration:", err)
	}

	// Initialize logger
	logger.InitLogger(cfg.Logger.Level, cfg.Logger.Format)
	logger.Info("Starting User Management Service")

	// Initialize database repository
	repo, err := repository.NewUserRepository(cfg)
	if err != nil {
		logger.Fatal("Failed to initialize repository:", err)
	}

	// Initialize service
	userService := service.NewUserService(repo, cfg)

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	// Initialize handlers
	handler := handlers.NewHandler(userService, cfg)

	// Health check
	router.GET("/health", handler.HealthCheck)

	// Public routes (no auth required)
	public := router.Group("/api/v1")
	{
		public.POST("/users/register", handler.Register)
		public.POST("/users/login", handler.Login)
		public.POST("/users/refresh", handler.RefreshToken)
	}

	// Protected routes (auth required)
	protected := router.Group("/api/v1")
	protected.Use(handler.AuthMiddleware())
	{
		protected.GET("/users/profile", handler.GetProfile)
		protected.PUT("/users/profile", handler.UpdateProfile)
		protected.DELETE("/users/profile", handler.DeleteProfile)
		protected.POST("/users/logout", handler.Logout)
		protected.GET("/users/:id", handler.GetUserByID)
		protected.GET("/users", handler.GetUsers)
	}

	// Start HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  time.Duration(cfg.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(cfg.Server.WriteTimeout) * time.Second,
	}

	go func() {
		logger.Info("HTTP server starting on port", cfg.Server.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start HTTP server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down User Management Service...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("HTTP server forced to shutdown:", err)
	}

	// Close database connections
	repo.Close()
	logger.Info("User Management Service stopped")
}
