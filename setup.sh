#!/bin/bash

# Video Optimizer Docker Setup Script
# This script helps you get started with the Video Optimizer Docker setup

set -e

echo "🎬 Video Optimizer Docker Setup"
echo "================================"

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create directories if they don't exist
echo "📁 Creating directories..."
mkdir -p videos output logs

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "✅ Please edit .env file with your configurations"
fi

# Build and start services
echo "🔨 Building Docker images..."
docker-compose build --no-cache

echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check service health
echo "🏥 Checking service health..."

# Check MongoDB
if docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "✅ MongoDB is running"
else
    echo "❌ MongoDB is not responding"
fi

# Check Backend
if curl -f http://localhost:8001/api/ > /dev/null 2>&1; then
    echo "✅ Backend API is running"
else
    echo "❌ Backend API is not responding"
fi

# Check Frontend
if curl -f http://localhost:3000/ > /dev/null 2>&1; then
    echo "✅ Frontend is running"
else
    echo "❌ Frontend is not responding"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Service URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend API: http://localhost:8001/api"
echo "   MongoDB: localhost:27017"
echo ""
echo "📂 Directories:"
echo "   Video Input: ./videos (place your video files here)"
echo "   Video Output: ./output (processed videos will be saved here)"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: docker-compose logs -f"
echo "   Stop services: docker-compose down"
echo "   Restart services: docker-compose restart"
echo "   Update images: docker-compose pull && docker-compose up -d"
echo ""
echo "💡 Tip: Place your video files in the './videos' directory and they'll be accessible within the containers."