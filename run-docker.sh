#!/bin/bash

# Slideshow App Docker Runner
# This script builds and runs the containerized slideshow application

echo "🎬 Starting Slideshow App in Docker..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Rebuild the frontend so the backend serves the latest assets
echo "🔧 Rebuilding frontend..."
(cd frontend/my-app && npm ci && npm run build && rm -rf ../../backend/frontend-build && cp -r build ../../backend/frontend-build)

# Build and start the containers
echo "🏗️  Building and starting containers..."
docker-compose up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
echo "🔍 Checking service status..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Services are running successfully!"
    echo ""
    echo "🌐 Application URLs:"
    echo "   Frontend: http://localhost:5173"
    echo "   Backend API: http://localhost:3000"
    echo ""
    echo "📊 To view logs:"
    echo "   docker-compose logs -f"
    echo ""
    echo "🛑 To stop the application:"
    echo "   docker-compose down"
    echo ""
    echo "🗑️  To remove all containers and volumes:"
    echo "   docker-compose down -v"
else
    echo "❌ Some services failed to start. Check logs with:"
    echo "   docker-compose logs"
    exit 1
fi
