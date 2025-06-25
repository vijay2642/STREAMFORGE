#!/bin/bash

# StreamForge Cloud Deployment Script
# This script helps deploy StreamForge to various cloud platforms

set -e  # Exit on any error

echo "🚀 StreamForge Cloud Deployment"
echo "================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if required files exist
check_requirements() {
    print_info "Checking requirements..."
    
    if [ ! -f "go.mod" ]; then
        print_error "go.mod not found. Make sure you're in the StreamForge root directory."
        exit 1
    fi
    
    if [ ! -d "services" ]; then
        print_error "services directory not found. Make sure you're in the StreamForge root directory."
        exit 1
    fi
    
    if [ ! -d "web" ]; then
        print_error "web directory not found. Make sure you're in the StreamForge root directory."
        exit 1
    fi
    
    print_status "All required files found!"
}

# Railway deployment
deploy_railway() {
    print_info "Starting Railway deployment..."
    
    # Check if Railway CLI is installed
    if ! command -v railway &> /dev/null; then
        print_warning "Railway CLI not found. Installing..."
        npm install -g @railway/cli
    fi
    
    print_info "Logging into Railway..."
    railway login
    
    print_info "Creating new Railway project..."
    railway init
    
    print_info "Adding PostgreSQL database..."
    railway add postgresql
    
    print_info "Deploying services..."
    railway deploy
    
    print_status "Railway deployment complete!"
    print_info "Check your Railway dashboard for service URLs: https://railway.app/dashboard"
}

# Google Cloud deployment
deploy_gcloud() {
    print_info "Starting Google Cloud deployment..."
    
    # Check if gcloud CLI is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI not found. Please install it first:"
        print_info "Mac: brew install google-cloud-sdk"
        print_info "Windows: Download from https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Get project ID
    read -p "Enter your Google Cloud Project ID: " PROJECT_ID
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "Project ID is required!"
        exit 1
    fi
    
    print_info "Setting up Google Cloud project: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
    
    print_info "Enabling required APIs..."
    gcloud services enable run.googleapis.com
    gcloud services enable sql-component.googleapis.com
    gcloud services enable storage.googleapis.com
    gcloud services enable containerregistry.googleapis.com
    
    print_info "Creating database instance..."
    read -p "Enter database password: " -s DB_PASSWORD
    echo ""
    
    gcloud sql instances create streamforge-db \
        --database-version=POSTGRES_13 \
        --tier=db-f1-micro \
        --region=us-central1 || print_warning "Database instance might already exist"
    
    gcloud sql databases create streamforge --instance=streamforge-db || print_warning "Database might already exist"
    
    gcloud sql users create streamforge-user \
        --instance=streamforge-db \
        --password=$DB_PASSWORD || print_warning "Database user might already exist"
    
    print_info "Deploying services to Cloud Run..."
    
    # Deploy transcoder
    cd services/transcoder
    gcloud run deploy streamforge-transcoder \
        --source . \
        --region us-central1 \
        --allow-unauthenticated \
        --memory 2Gi \
        --cpu 2
    cd ../..
    
    # Deploy stream processing
    cd services/stream-processing
    gcloud run deploy streamforge-processor \
        --source . \
        --region us-central1 \
        --allow-unauthenticated
    cd ../..
    
    # Deploy user management
    cd services/user-management
    gcloud run deploy streamforge-users \
        --source . \
        --region us-central1 \
        --allow-unauthenticated
    cd ../..
    
    # Deploy web interface
    cd web
    gcloud run deploy streamforge-web \
        --source . \
        --region us-central1 \
        --allow-unauthenticated
    cd ..
    
    print_status "Google Cloud deployment complete!"
    print_info "Your services are now running on Google Cloud Run"
}

# DigitalOcean deployment
deploy_digitalocean() {
    print_info "Starting DigitalOcean deployment..."
    
    # Check if doctl is installed
    if ! command -v doctl &> /dev/null; then
        print_warning "DigitalOcean CLI not found. Installing..."
        # Installation varies by OS, provide instructions
        print_info "Please install doctl first:"
        print_info "Mac: brew install doctl"
        print_info "Linux: snap install doctl"
        print_info "Windows: Download from https://github.com/digitalocean/doctl/releases"
        exit 1
    fi
    
    print_info "Authenticating with DigitalOcean..."
    doctl auth init
    
    print_info "Creating DigitalOcean App..."
    print_warning "Please create your app manually at https://cloud.digitalocean.com/apps"
    print_info "1. Go to Apps section"
    print_info "2. Click 'Create App'"
    print_info "3. Connect your GitHub repository"
    print_info "4. DigitalOcean will auto-detect your services"
    
    print_status "DigitalOcean setup instructions provided!"
}

# Docker Compose for local testing
deploy_local() {
    print_info "Setting up local Docker deployment..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Compose first."
        exit 1
    fi
    
    print_info "Building and starting services..."
    docker-compose up --build -d
    
    print_status "Local deployment complete!"
    print_info "Services are running at:"
    print_info "Web Interface: http://localhost:8082"
    print_info "Transcoder: http://localhost:8080"
    print_info "Stream Processing: http://localhost:8081"
    print_info "User Management: http://localhost:8083"
}

# Main menu
main_menu() {
    echo ""
    echo "Choose your deployment method:"
    echo "1) Railway (Easiest - Recommended for beginners)"
    echo "2) Google Cloud Platform (Best for scalability)"
    echo "3) DigitalOcean (Good balance of features and cost)"
    echo "4) Local Docker (For testing)"
    echo "5) Exit"
    echo ""
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            deploy_railway
            ;;
        2)
            deploy_gcloud
            ;;
        3)
            deploy_digitalocean
            ;;
        4)
            deploy_local
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please try again."
            main_menu
            ;;
    esac
}

# Main execution
main() {
    check_requirements
    main_menu
    
    echo ""
    print_status "Deployment process completed!"
    print_info "Don't forget to:"
    print_info "1. Test your deployment thoroughly"
    print_info "2. Set up monitoring and alerts"
    print_info "3. Configure your domain (if needed)"
    print_info "4. Set up HTTPS certificates"
    echo ""
    print_info "For detailed instructions, check CLOUD_DEPLOYMENT_GUIDE.md"
}

# Run main function
main "$@" 