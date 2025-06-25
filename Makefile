.PHONY: build test clean up down logs init-db

# Build all services
build-all:
	@echo "Building all services..."
	@go build -o bin/stream-ingestion ./services/stream-ingestion
	@go build -o bin/stream-processing ./services/stream-processing
	@go build -o bin/user-management ./services/user-management
	@go build -o bin/stream-metadata ./services/stream-metadata
	@go build -o bin/api-gateway ./services/api-gateway
	@go build -o bin/notification ./services/notification
	@go build -o bin/analytics ./services/analytics
	@go build -o bin/stream-distribution ./services/stream-distribution
	@go build -o bin/transcoder ./services/transcoder

# Build individual services
build-ingestion:
	@go build -o bin/stream-ingestion ./services/stream-ingestion

build-processing:
	@go build -o bin/stream-processing ./services/stream-processing

build-distribution:
	@go build -o bin/stream-distribution ./services/stream-distribution

build-user:
	@go build -o bin/user-management ./services/user-management

build-metadata:
	@go build -o bin/stream-metadata ./services/stream-metadata

build-gateway:
	@go build -o bin/api-gateway ./services/api-gateway

build-notification:
	@go build -o bin/notification ./services/notification

build-analytics:
	@go build -o bin/analytics ./services/analytics

build-transcoder:
	@go build -o bin/transcoder ./services/transcoder

# Test all services
test-all:
	@echo "Running tests for all services..."
	@go test ./services/stream-ingestion/...
	@go test ./services/stream-processing/...
	@go test ./services/user-management/...
	@go test ./services/stream-metadata/...
	@go test ./services/api-gateway/...
	@go test ./services/notification/...
	@go test ./services/analytics/...
	@go test ./services/stream-distribution/...
	@go test ./pkg/...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/
	@docker-compose down -v
	@docker system prune -f

# Docker operations
up:
	@echo "Starting all services with Docker Compose..."
	@docker-compose up -d

down:
	@echo "Stopping all services..."
	@docker-compose down

restart:
	@echo "Restarting all services..."
	@docker-compose restart

logs:
	@docker-compose logs -f

logs-service:
	@docker-compose logs -f $(SERVICE)

# Database operations
init-db:
	@echo "Initializing database..."
	@docker-compose exec postgres psql -U streamforge -d streamforge -f /docker-entrypoint-initdb.d/init-db.sql

migrate-up:
	@echo "Running database migrations..."
	@docker-compose exec postgres psql -U streamforge -d streamforge -c "SELECT 'Migrations would run here';"

migrate-down:
	@echo "Rolling back database migrations..."
	@docker-compose exec postgres psql -U streamforge -d streamforge -c "SELECT 'Rollback would run here';"

# Development operations
dev-up:
	@echo "Starting development environment..."
	@docker-compose up -d postgres redis
	@sleep 5
	@make init-db

dev-down:
	@echo "Stopping development environment..."
	@docker-compose down

# Run individual services locally
run-ingestion:
	@go run ./services/stream-ingestion

run-processing:
	@go run ./services/stream-processing

run-distribution:
	@go run ./services/stream-distribution

run-user:
	@go run ./services/user-management

run-metadata:
	@go run ./services/stream-metadata

run-gateway:
	@go run ./services/api-gateway

run-notification:
	@go run ./services/notification

run-analytics:
	@go run ./services/analytics

run-transcoder:
	@go run ./services/transcoder

# Docker build operations
docker-build-all:
	@echo "Building all Docker images..."
	@docker-compose build

docker-build-service:
	@echo "Building Docker image for $(SERVICE)..."
	@docker-compose build $(SERVICE)

# Monitoring and health checks
health-check:
	@echo "Checking service health..."
	@curl -f http://localhost:8080/health || echo "API Gateway: DOWN"
	@curl -f http://localhost:8081/health || echo "Stream Ingestion: DOWN"
	@curl -f http://localhost:8082/health || echo "Stream Processing: DOWN"
	@curl -f http://localhost:8083/health || echo "Stream Distribution: DOWN"
	@curl -f http://localhost:8084/health || echo "User Management: DOWN"
	@curl -f http://localhost:8085/health || echo "Stream Metadata: DOWN"
	@curl -f http://localhost:8086/health || echo "Notification: DOWN"
	@curl -f http://localhost:8087/health || echo "Analytics: DOWN"
	@curl -f http://localhost:8083/health || echo "Transcoder: DOWN"

# Code quality
lint:
	@echo "Running linters..."
	@golangci-lint run ./...

fmt:
	@echo "Formatting code..."
	@go fmt ./...

vet:
	@echo "Running go vet..."
	@go vet ./...

# Dependencies
deps:
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy

# Generate code (protobuf, swagger, etc.)
generate:
	@echo "Generating code..."
	@go generate ./...

# RTMP Streaming Operations
rtmp-up:
	@echo "Starting RTMP streaming stack..."
	@docker-compose -f docker-compose-rtmp.yml up -d

rtmp-down:
	@echo "Stopping RTMP streaming stack..."
	@docker-compose -f docker-compose-rtmp.yml down

rtmp-logs:
	@docker-compose -f docker-compose-rtmp.yml logs -f

# Transcoding Operations
start-transcoder:
	@echo "Starting transcoder for stream: $(STREAM)"
	@curl -X POST http://localhost:8083/transcode/start/$(STREAM) || echo "Failed to start transcoder"

stop-transcoder:
	@echo "Stopping transcoder for stream: $(STREAM)"
	@curl -X POST http://localhost:8083/transcode/stop/$(STREAM) || echo "Failed to stop transcoder"

transcoder-status:
	@echo "Getting transcoder status for stream: $(STREAM)"
	@curl http://localhost:8083/transcode/status/$(STREAM) | jq || echo "Failed to get status"

active-transcoders:
	@echo "Getting all active transcoders..."
	@curl http://localhost:8083/transcode/active | jq || echo "Failed to get active transcoders"

# Help
help:
	@echo "Available commands:"
	@echo "  build-all        - Build all services"
	@echo "  test-all         - Run all tests"
	@echo "  clean           - Clean build artifacts"
	@echo "  up              - Start all services with Docker"
	@echo "  down            - Stop all services"
	@echo "  logs            - Show logs from all services"
	@echo "  init-db         - Initialize database"
	@echo "  dev-up          - Start development environment"
	@echo "  health-check    - Check service health"
	@echo "  lint            - Run linters"
	@echo "  fmt             - Format code"
	@echo "  deps            - Install dependencies"
	@echo "  help            - Show this help" 