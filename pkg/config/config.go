package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Stream   StreamConfig   `mapstructure:"stream"`
	Auth     AuthConfig     `mapstructure:"auth"`
	Logger   LoggerConfig   `mapstructure:"logger"`
}

type ServerConfig struct {
	Host         string `mapstructure:"host"`
	Port         int    `mapstructure:"port"`
	GRPCPort     int    `mapstructure:"grpc_port"`
	ReadTimeout  int    `mapstructure:"read_timeout"`
	WriteTimeout int    `mapstructure:"write_timeout"`
}

type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	DBName   string `mapstructure:"dbname"`
	SSLMode  string `mapstructure:"sslmode"`
}

type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

type StreamConfig struct {
	RTMPPort        int    `mapstructure:"rtmp_port"`
	HLSPath         string `mapstructure:"hls_path"`
	DASHPath        string `mapstructure:"dash_path"`
	SegmentDuration int    `mapstructure:"segment_duration"`
	MaxBitrate      int    `mapstructure:"max_bitrate"`
}

type AuthConfig struct {
	JWTSecret     string `mapstructure:"jwt_secret"`
	TokenDuration int    `mapstructure:"token_duration"`
}

type LoggerConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
}

// Load loads configuration from environment variables and config files
func Load(serviceName string) (*Config, error) {
	config := &Config{}

	// Set defaults
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.grpc_port", 9090)
	viper.SetDefault("server.read_timeout", 30)
	viper.SetDefault("server.write_timeout", 30)

	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.sslmode", "disable")

	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", 6379)
	viper.SetDefault("redis.db", 0)

	viper.SetDefault("stream.rtmp_port", 1935)
	viper.SetDefault("stream.hls_path", "/tmp/hls_shared")
	viper.SetDefault("stream.dash_path", "/tmp/dash")
	viper.SetDefault("stream.segment_duration", 4)
	viper.SetDefault("stream.max_bitrate", 2000)

	viper.SetDefault("auth.token_duration", 24)
	viper.SetDefault("logger.level", "info")
	viper.SetDefault("logger.format", "json")

	// Load from environment variables
	viper.AutomaticEnv()
	viper.SetEnvPrefix(serviceName)

	// Load from config file if exists
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("../config")
	viper.AddConfigPath("../../config")

	if err := viper.ReadInConfig(); err != nil {
		// Config file not found, continue with env vars and defaults
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
	}

	if err := viper.Unmarshal(config); err != nil {
		return nil, fmt.Errorf("error unmarshaling config: %w", err)
	}

	// Override with environment variables
	if host := os.Getenv(serviceName + "_SERVER_HOST"); host != "" {
		config.Server.Host = host
	}
	if port := os.Getenv(serviceName + "_SERVER_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			config.Server.Port = p
		}
	}

	return config, nil
}

// GetDatabaseDSN returns the database connection string
func (c *Config) GetDatabaseDSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Database.Host, c.Database.Port, c.Database.User, c.Database.Password, c.Database.DBName, c.Database.SSLMode)
}

// GetRedisAddr returns the Redis address
func (c *Config) GetRedisAddr() string {
	return fmt.Sprintf("%s:%d", c.Redis.Host, c.Redis.Port)
}
