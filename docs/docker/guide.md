# Docker Guide

This guide explains how to run and build the Slideshow Web App with Docker and summarizes the container setup.

## Quick Start

```bash
# Recommended helper script
chmod +x run-docker.sh
./run-docker.sh
```

The script builds the images and starts both the backend (port 3000) and frontend (port 5173) containers. Project data is stored in `./backend/projects` on the host so it persists between runs.

## docker-compose

The `docker-compose.yml` file defines two services:

- **backend** – Node.js API with FFmpeg, ImageMagick, Python (madmom) and yt-dlp installed.
- **frontend** – SvelteKit UI that communicates with the backend via REST and WebSocket.

Volumes mount the source code and project directory for development convenience. Environment variables like `NODE_ENV` and `PORT` can be set in a `.env` file.

## Implementation Notes

The Docker implementation includes:

- Dockerfiles for backend and frontend images
- Compose configuration to run both services on a shared network
- Utility commands for rebuilding, viewing logs and cleaning up images

This setup provides a production-ready containerized environment while keeping the workflow simple for local development.
