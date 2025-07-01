# 🐳 Running Slideshow App with Docker

This guide shows you how to run the Slideshow Creator application using Docker containers.

## Prerequisites

- Docker Desktop installed and running
- At least 4GB of available RAM
- 2GB of free disk space

## Quick Start

### Option 1: Using the Run Script (Recommended)

```bash
# Make the script executable and run it
chmod +x run-docker.sh
./run-docker.sh
```

### Option 2: Manual Docker Compose

```bash
# Build and start all services
docker-compose up --build -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Application URLs

Once running, access the application at:

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:3000

## Docker Services

The application consists of two main services:

### Backend Service
- **Container**: `slideshow-backend`
- **Port**: 3000
- **Features**:
  - Node.js Express API
  - FFmpeg for video processing
  - ImageMagick for image processing
  - Python with madmom for audio analysis
  - yt-dlp for YouTube audio downloads

### Frontend Service
- **Container**: `slideshow-frontend` 
- **Port**: 5173
- **Features**:
  - SvelteKit application
  - Modern responsive UI
  - Real-time WebSocket updates

## Data Persistence

Projects and uploaded files are stored in:
- Host directory: `./backend/projects`
- Container directory: `/app/projects`

This ensures your projects persist between container restarts.

## Useful Commands

### View running containers
```bash
docker-compose ps
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Restart services
```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart backend
```

### Stop and remove containers
```bash
# Stop containers
docker-compose down

# Stop and remove volumes (deletes projects!)
docker-compose down -v
```

### Rebuild containers
```bash
# Rebuild and restart
docker-compose up --build -d
```

## Troubleshooting

### Service won't start
1. Check Docker is running: `docker info`
2. Check logs: `docker-compose logs [service-name]`
3. Restart Docker Desktop
4. Try rebuilding: `docker-compose up --build -d`

### Port conflicts
If ports 3000 or 5173 are already in use:
1. Stop the conflicting services
2. Or modify the ports in `docker-compose.yml`

### Out of disk space
```bash
# Clean up unused Docker resources
docker system prune -a
```

### Performance issues
- Increase Docker Desktop memory allocation to 4GB+
- Close other memory-intensive applications

## Development Mode

For development with hot reloading:

```bash
# Run in development mode
docker-compose -f docker-compose.dev.yml up --build
```

## Environment Variables

You can customize the application with environment variables:

```bash
# Create .env file
NODE_ENV=production
PORT=3000
PUBLIC_API_URL=http://localhost:3000
```

## Security Notes

The application runs with the following considerations:
- Containers run as non-root users where possible
- File uploads are restricted to images and audio
- Processing is isolated within containers
- No external database connections required

---

For more information about the application features, see the main README.md file.