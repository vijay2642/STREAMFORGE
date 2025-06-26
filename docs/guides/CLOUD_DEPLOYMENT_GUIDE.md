# 🌐 StreamForge Cloud Deployment Guide

**Complete guide to deploy StreamForge to the cloud from scratch - designed for non-IT users!**

## 📋 Overview

This guide will help you deploy your StreamForge video streaming platform to the cloud so anyone can access it from anywhere. We'll use the **easiest and most beginner-friendly** approach.

## 🎯 What We'll Deploy

Your StreamForge includes:
- **Video Transcoding Service** (converts video to multiple qualities)
- **Stream Processing Service** (handles live streams)
- **User Management Service** (manages users)
- **Web Player** (the video player interface you just fixed)
- **Database** (stores stream and user data)
- **NGINX** (handles video streaming)

## 🏆 Recommended: Google Cloud Platform (GCP)

**Why GCP?**
- ✅ **$300 free credit** for new users (lasts 3+ months)
- ✅ **Easiest setup** with one-click deployments
- ✅ **Auto-scaling** handles traffic spikes
- ✅ **Built-in monitoring** shows performance
- ✅ **Excellent documentation** and support

---

## 🚀 Method 1: Google Cloud Run (EASIEST - Recommended)

**Perfect for: Beginners, small to medium traffic, cost-effective**

### Step 1: Setup Google Cloud Account

1. **Go to** [cloud.google.com](https://cloud.google.com)
2. **Click** "Get started for free"
3. **Sign up** with your Google account
4. **Verify** your identity (credit card required but won't be charged)
5. **Claim** your $300 free credit

### Step 2: Install Google Cloud CLI

**On Mac (using Terminal):**
```bash
# Install using Homebrew
brew install google-cloud-sdk

# Initialize and login
gcloud init
gcloud auth login
```

**On Windows:**
1. Download [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
2. Run the installer
3. Open Command Prompt and run: `gcloud init`

### Step 3: Prepare Your Project

1. **Create a new project** in Google Cloud Console
2. **Enable required APIs:**
   - Cloud Run API
   - Cloud SQL API
   - Cloud Storage API
   - Container Registry API

```bash
# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Enable APIs
gcloud services enable run.googleapis.com
gcloud services enable sql-component.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### Step 4: Setup Database

```bash
# Create PostgreSQL database instance
gcloud sql instances create streamforge-db \
    --database-version=POSTGRES_13 \
    --tier=db-f1-micro \
    --region=us-central1

# Create database
gcloud sql databases create streamforge --instance=streamforge-db

# Create user
gcloud sql users create streamforge-user \
    --instance=streamforge-db \
    --password=your-secure-password
```

### Step 5: Deploy Services

**Create deployment script:**

```bash
#!/bin/bash
# deploy.sh

# Build and deploy transcoder service
cd services/transcoder
gcloud run deploy streamforge-transcoder \
    --source . \
    --region us-central1 \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2

# Deploy stream processing
cd ../stream-processing
gcloud run deploy streamforge-processor \
    --source . \
    --region us-central1 \
    --allow-unauthenticated

# Deploy user management
cd ../user-management
gcloud run deploy streamforge-users \
    --source . \
    --region us-central1 \
    --allow-unauthenticated

# Deploy web interface
cd ../../web
gcloud run deploy streamforge-web \
    --source . \
    --region us-central1 \
    --allow-unauthenticated
```

### Step 6: Setup Domain (Optional)

1. **Buy a domain** (e.g., yourstream.com) from Google Domains or any registrar
2. **Map domain** to your Cloud Run service:

```bash
gcloud run domain-mappings create \
    --service streamforge-web \
    --domain yourstream.com \
    --region us-central1
```

### Step 7: Configure Environment Variables

```bash
# Set database connection
gcloud run services update streamforge-transcoder \
    --set-env-vars="DATABASE_URL=postgresql://streamforge-user:your-password@/streamforge?host=/cloudsql/YOUR_PROJECT_ID:us-central1:streamforge-db"
```

**Estimated Monthly Cost:** $20-50 for moderate usage

---

## 🚀 Method 2: Railway (SIMPLEST)

**Perfect for: Complete beginners, prototypes, low traffic**

### Step 1: Setup Railway Account

1. **Go to** [railway.app](https://railway.app)
2. **Sign up** with GitHub account
3. **Connect** your StreamForge repository

### Step 2: One-Click Deploy

1. **Click** "New Project"
2. **Select** "Deploy from GitHub repo"
3. **Choose** your StreamForge repository
4. **Railway automatically:**
   - Detects your services
   - Builds Docker containers
   - Deploys everything
   - Provides URLs

### Step 3: Add Database

1. **Click** "New" → "Database" → "PostgreSQL"
2. **Railway automatically** connects it to your services

### Step 4: Configure Domain

1. **Go to** your service settings
2. **Click** "Generate Domain" or add custom domain
3. **Done!** Your app is live

**Estimated Monthly Cost:** $5-20 for low traffic

---

## 🚀 Method 3: DigitalOcean App Platform

**Perfect for: Predictable pricing, good performance**

### Step 1: Setup DigitalOcean Account

1. **Go to** [digitalocean.com](https://digitalocean.com)
2. **Sign up** and get $200 credit
3. **Verify** your account

### Step 2: Create App

1. **Go to** Apps section
2. **Click** "Create App"
3. **Connect** GitHub repository
4. **DigitalOcean detects** your services automatically

### Step 3: Configure Services

- **Transcoder:** 2 vCPU, 4GB RAM
- **Processor:** 1 vCPU, 2GB RAM  
- **User Management:** 1 vCPU, 1GB RAM
- **Web:** 1 vCPU, 1GB RAM

### Step 4: Add Database

1. **Click** "Create" → "Database"
2. **Choose** PostgreSQL
3. **Select** Basic plan ($15/month)

**Estimated Monthly Cost:** $25-60

---

## 🔧 Required Dockerfile Updates

**For each service, create a `Dockerfile`:**

### services/transcoder/Dockerfile
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o transcoder main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates ffmpeg
WORKDIR /root/
COPY --from=builder /app/transcoder .
EXPOSE 8080
CMD ["./transcoder"]
```

### services/stream-processing/Dockerfile
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o processor main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/processor .
EXPOSE 8081
CMD ["./processor"]
```

### services/user-management/Dockerfile
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o users main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/users .
EXPOSE 8083
CMD ["./users"]
```

### web/Dockerfile
```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

### web/nginx.conf
```nginx
events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }
        
        location /api/ {
            proxy_pass http://streamforge-processor:8081/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

---

## 🎯 Quick Start Script

**Create this script to automate deployment:**

### deploy-to-cloud.sh
```bash
#!/bin/bash

echo "🚀 StreamForge Cloud Deployment"
echo "================================"

# Check if user wants Railway (easiest)
read -p "Use Railway for simplest deployment? (y/n): " use_railway

if [ "$use_railway" = "y" ]; then
    echo "📦 Installing Railway CLI..."
    npm install -g @railway/cli
    
    echo "🔐 Login to Railway..."
    railway login
    
    echo "🚀 Deploying to Railway..."
    railway deploy
    
    echo "✅ Deployment complete! Check Railway dashboard for URLs."
else
    echo "📋 For Google Cloud or DigitalOcean:"
    echo "1. Follow the manual steps in this guide"
    echo "2. Or run the specific deployment scripts above"
fi
```

---

## 🌟 Post-Deployment Checklist

### 1. Test Your Deployment
- [ ] **Web interface** loads correctly
- [ ] **Video upload** works
- [ ] **Transcoding** processes videos
- [ ] **Live streaming** functions
- [ ] **Timeline dragging** works (your recent fix!)

### 2. Setup Monitoring
- [ ] **Enable logging** in cloud platform
- [ ] **Set up alerts** for errors
- [ ] **Monitor resource usage**

### 3. Security
- [ ] **Enable HTTPS** (usually automatic)
- [ ] **Set up authentication** for admin features
- [ ] **Configure CORS** for your domain

### 4. Performance
- [ ] **Test with multiple users**
- [ ] **Monitor response times**
- [ ] **Scale resources** if needed

---

## 💰 Cost Estimation

### Small Usage (1-10 users)
- **Railway:** $5-15/month
- **Google Cloud:** $10-30/month
- **DigitalOcean:** $15-40/month

### Medium Usage (10-100 users)
- **Railway:** $20-50/month
- **Google Cloud:** $30-100/month
- **DigitalOcean:** $40-120/month

### Large Usage (100+ users)
- **Google Cloud:** $100-500/month (with auto-scaling)
- **DigitalOcean:** $150-400/month

---

## 🆘 Troubleshooting

### Common Issues:

#### "Service won't start"
```bash
# Check logs
gcloud run services get-iam-policy YOUR_SERVICE
kubectl logs YOUR_POD_NAME
```

#### "Database connection failed"
- ✅ **Check** connection string
- ✅ **Verify** database credentials  
- ✅ **Ensure** database is running

#### "Out of memory"
- ✅ **Increase** memory allocation
- ✅ **Check** for memory leaks
- ✅ **Optimize** video processing

#### "Slow video processing"
- ✅ **Increase** CPU allocation
- ✅ **Use** GPU instances for transcoding
- ✅ **Implement** queue system

---

## 📞 Support Resources

### Free Support:
- **Google Cloud:** [Documentation](https://cloud.google.com/docs)
- **Railway:** [Discord Community](https://discord.gg/railway)
- **DigitalOcean:** [Community Tutorials](https://www.digitalocean.com/community)

### Paid Support:
- **Google Cloud:** Professional support plans
- **AWS:** Enterprise support
- **DigitalOcean:** Business support

---

## 🎉 Congratulations!

Once deployed, your StreamForge platform will be accessible worldwide! Users can:
- ✅ **Upload and stream videos**
- ✅ **Watch in multiple qualities**
- ✅ **Use the timeline dragging** you just perfected
- ✅ **Access from any device**

Your streaming platform is now **production-ready** and **scalable**! 🎬🌍

---

## 📚 Next Steps

1. **Add CDN** (CloudFlare) for faster video delivery
2. **Implement user authentication** (Auth0, Firebase)
3. **Add payment system** (Stripe) for premium features
4. **Setup analytics** (Google Analytics)
5. **Add mobile app** (React Native, Flutter)

**Happy Streaming!** 🚀📺 