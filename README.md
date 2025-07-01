# Slideshow Web App

This repository turns the original slideshow shell scripts into a Docker-packaged web application.
It contains a Svelte frontend and a comprehensive Node.js API backend that provides full project management,
file uploads, audio analysis, and slideshow processing capabilities.

## 🚀 Features

- **Project Management**: Create, organize, and manage multiple slideshow projects
- **Smart File Uploads**: Support for images (JPEG, PNG, HEIC) and audio files
- **YouTube Integration**: Download audio directly from YouTube with time-based extraction
- **Audio Analysis**: Beat detection using madmom for perfect sync, plus emotional crossfade timing
- **Real-time Processing**: WebSocket updates during video generation
- **Docker Ready**: Complete containerized environment with all dependencies

## Architecture

```
docker-compose.yml
└─ slideshow/
   ├─ backend/
   │  ├─ api/                    # REST API modules
   │  │  ├─ projects.js          # Project CRUD operations
   │  │  ├─ uploads.js           # File uploads & YouTube
   │  │  ├─ analyze.js           # Audio analysis & beat detection
   │  │  └─ process.js           # Slideshow generation
   │  ├─ process_single_*.sh     # Adapted shell scripts
   │  └─ index.js                # Express server with WebSocket
   ├─ frontend/                  # SvelteKit single page app
   └─ projects/                  # User projects (mounted volume)
      └─ {projectId}/
         ├─ metadata.json        # Project configuration
         ├─ *.jpg/png/heic       # Images
         ├─ *.mp3/wav/m4a        # Audio files
         ├─ audio.txt            # YouTube URL (optional)
         └─ slideshow.mp4        # Generated video
```

The container includes:
- **Media Processing**: `ffmpeg`, `libheif-examples`, `yt-dlp`
- **Audio Analysis**: Python 3 with `madmom` for beat detection
- **Shell Support**: `zsh` for script compatibility

## Quick Start

### First-Time Setup

```bash
# Install all development dependencies (Docker, Node.js, Python, etc.)
./setup-dev-requirements.sh

# Verify your development environment
./verify-dev-setup.sh

# Build and test the application
./docker-test-runner.sh
```

### Using Docker (Recommended)

```bash
# Build and test
./docker-test-runner.sh

# Or manually
docker build -t slideshow .
docker run -p 3000:3000 -v "$(pwd)/projects:/app/projects" slideshow
```

### Development Mode

```bash
cd backend
npm install
npm run dev
```

Then open [http://localhost:3000](http://localhost:3000)

## 📚 Documentation

- **[API Implementation Guide](API_IMPLEMENTATION.md)** - Detailed technical documentation
- **[API Reference](API_REFERENCE.md)** - Complete endpoint documentation

## 🔧 API Endpoints

### Projects
- `GET /api/projects` - List all projects
- `POST /api/projects` - Create new project
- `GET /api/projects/:id` - Get project details
- `PUT /api/projects/:id` - Update project
- `DELETE /api/projects/:id` - Delete project

### File Management
- `POST /api/upload/:id/images` - Upload images
- `POST /api/upload/:id/audio` - Upload audio
- `POST /api/upload/:id/youtube-download` - Download from YouTube

### Audio Analysis
- `POST /api/analyze/:id/analyze` - Analyze audio and calculate required images

### Processing
- `POST /api/process/:id/process` - Generate slideshow
- `GET /api/process/:id/status` - Check processing status
- `GET /api/process/:id/download` - Download video

## 🎵 Audio Analysis Modes

### Normal Mode (Beat-Synced)
Uses madmom neural network for accurate downbeat detection:
```json
{
  "type": "beat-synced",
  "requiredImages": 45,
  "downbeats": [0.5, 2.1, 3.8, ...]
}
```

### Emotional Mode (Crossfade)
Calculates smooth crossfade timing for emotional impact:
```json
{
  "type": "emotional", 
  "requiredImages": 30,
  "imageDisplayTime": 5.2,
  "crossfadeDuration": 3.0
}
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Full Docker build and test
./docker-test-runner.sh

# API tests only (requires running server)
./test-docker.sh
```

Tests cover:
- All API endpoints
- File uploads/downloads
- Audio analysis
- Error handling
- WebSocket communication

## 💻 Development

### Backend Structure
```
backend/
├─ api/
│  ├─ projects.js    # Project management
│  ├─ uploads.js     # File handling
│  ├─ analyze.js     # Audio analysis
│  └─ process.js     # Video generation
├─ process_single_project.sh      # Normal slideshow
├─ process_single_emotional.sh    # Emotional slideshow
└─ index.js          # Main server
```

### Key Technologies
- **Backend**: Node.js, Express, WebSocket
- **Audio**: Python madmom for beat detection
- **Video**: ffmpeg for generation
- **Frontend**: SvelteKit (ready for development)

## 🚀 Usage Workflow

1. **Create Project**: Use web interface or API
2. **Upload Content**: Add images and audio files
3. **Analyze Audio**: Get recommended image count
4. **Process**: Generate slideshow with real-time updates
5. **Download**: Get final MP4 video

Example with YouTube:
```bash
curl -X POST http://localhost:3000/api/upload/project-123/youtube-download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://youtube.com/watch?v=...", "startTime": "00:30"}'
```

## 🔄 Migration from Shell Scripts

The implementation preserves all original functionality while adding:
- Web-based project management
- Real-time processing feedback  
- Advanced audio analysis
- Multi-project support
- File upload handling

All video generation logic remains identical for consistent quality.

## 📋 Requirements

- Docker (recommended)
- OR Node.js 18+ with Python 3 and ffmpeg

## 🤝 Contributing

See the implementation docs for technical details. The codebase is modular and well-tested.

## 📜 License

[Add your license information here]

