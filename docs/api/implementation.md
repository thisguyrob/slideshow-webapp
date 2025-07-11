# Slideshow Web App - API Implementation Documentation

## Overview

This document details the comprehensive backend API implementation that was added to transform the shell-script based slideshow generator into a full web application.

## Changes Made

### 1. Backend Dependencies

**File:** `backend/package.json`

Added the following dependencies:
- `multer` - File upload handling
- `cors` - Cross-origin resource sharing
- `ws` - WebSocket support for real-time updates
- `uuid` - Unique ID generation for projects

Added development script: `"dev": "node --watch index.js"`

### 2. Main Server Implementation

**File:** `backend/index.js`

**Before:** Simple static file server
**After:** Full API server with:
- CORS middleware
- JSON/form parsing
- WebSocket server for real-time updates
- Four API route modules
- Static file serving for both frontend and project files

### 3. API Routes Structure

Created modular API structure in `backend/api/`:

#### 3.1 Project Management (`api/projects.js`)

**Endpoints:**
- `GET /api/projects` - List all projects with metadata
- `POST /api/projects` - Create new project
- `GET /api/projects/:id` - Get project details and files
- `PUT /api/projects/:id` - Update project metadata
- `DELETE /api/projects/:id` - Delete project
- `POST /api/projects/:id/reorder` - Reorder images

**Features:**
- Automatic project directory creation
- Metadata management with JSON files
- File type detection (images, audio, video)
- YouTube URL detection from `audio.txt`

#### 3.2 File Upload Management (`api/uploads.js`)

**Endpoints:**
- `POST /api/upload/:id/images` - Upload multiple images
- `POST /api/upload/:id/audio` - Upload single audio file
- `POST /api/upload/:id/youtube` - Save YouTube URL only
- `POST /api/upload/:id/youtube-download` - Download and convert YouTube audio
- `DELETE /api/upload/:id/files/:filename` - Delete specific files

- Multer-based file upload with validation
- Support for images: JPEG, PNG, HEIC
- HEIC images are automatically converted to JPG using `heif-convert` when available, with fallbacks to `sips`, `ffmpeg`, and ImageMagick
- Support for audio: MP3, WAV, M4A, AAC
- YouTube URL validation
- yt-dlp integration for audio download with time-based extraction
- Audio offset storage in metadata

#### 3.3 Audio Analysis (`api/analyze.js`)

**Endpoints:**
- `POST /api/analyze/:id/analyze` - Analyze audio and calculate required images

**Features:**
- **Beat-synced analysis:** Uses madmom Python library for accurate downbeat detection
- **Emotional analysis:** Calculates crossfade timing for smooth transitions
- **Fallback analysis:** Time-based estimation when madmom unavailable
- **Multi-format support:** Works with any ffprobe-compatible audio format
- Results stored in project metadata

#### 3.4 Slideshow Processing (`api/process.js`)

**Endpoints:**
- `POST /api/process/:id/process` - Start slideshow generation
- `GET /api/process/:id/status` - Check processing status
- `POST /api/process/:id/cancel` - Cancel ongoing process
- `GET /api/process/:id/download` - Download generated video

**Features:**
- Integration with custom shell scripts
- Real-time progress updates via WebSocket
- Process management (start/stop/status)
- Automatic metadata usage for audio offsets
- Support for both normal and emotional modes

### 4. Shell Script Adaptation

Created wrapper scripts to work with single-project directories:

#### 4.1 Normal Mode (`process_single_project.sh`)
- Adapted from original `slideshow_builder.sh`
- Works with files directly in project directory
- Handles HEIC conversion, YouTube downloads, crossfades
- Uses same ffmpeg logic as original

#### 4.2 Emotional Mode (`process_single_emotional.sh`)
- Based on original emotional processing logic
- Calculates smooth crossfade timing
- Handles variable-length audio with proper fade in/out
- Optimized for emotional impact with longer transitions

### 5. Docker Enhancements

**File:** `Dockerfile`

Added Python ecosystem for audio analysis:
- `python3` and `python3-pip`
- `python3-numpy` and `python3-scipy` for numerical computation
- `libsndfile1` for audio file support
- `madmom` Python package for beat detection
- `zsh` for shell script compatibility

**Before:** ~200MB image with basic tools
**After:** ~800MB image with full audio analysis capabilities

### 6. Project Structure

**New Directory Structure:**
```
backend/
├── api/
│   ├── projects.js      # Project management
│   ├── uploads.js       # File uploads & YouTube
│   ├── process.js       # Slideshow processing
│   └── analyze.js       # Audio analysis
├── process_single_project.sh     # Normal slideshow wrapper
├── process_single_emotional.sh   # Emotional slideshow wrapper
├── index.js            # Main server
└── package.json        # Updated dependencies

projects/
└── {projectId}/
    ├── metadata.json   # Project metadata
    ├── *.jpg/png/heic  # Images
    ├── *.mp3/wav/m4a   # Audio files
    ├── audio.txt       # YouTube URL (optional)
    └── slideshow.mp4   # Generated video
```

### 7. Testing Infrastructure

#### 7.1 API Test Suite (`test-docker.sh`)
Comprehensive test coverage:
- Server health checks
- Full CRUD operations for projects
- File upload/download testing
- Audio analysis verification
- Error handling validation
- Cleanup verification

#### 7.2 Docker Test Runner (`docker-test-runner.sh`)
Automated build and test pipeline:
- Docker image building
- Container lifecycle management
- Server readiness checking
- Full test suite execution
- Automatic cleanup

## API Documentation

### Authentication
Currently no authentication - suitable for single-user deployments.

### Error Handling
All endpoints return consistent JSON error responses:
```json
{
  "error": "Description of error",
  "details": "Additional details when available"
}
```

### WebSocket Events
Real-time updates during processing:
```json
{
  "type": "progress",
  "projectId": "project-123",
  "message": "Processing...",
  "progress": 50,
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### File Serving
- Project files served at `/api/files/:projectId/:filename`
- Frontend build served at root `/`
- Proper MIME type detection

## Key Technical Decisions

1. **Modular API Structure:** Separated concerns into logical modules for maintainability
2. **Shell Script Wrappers:** Preserved existing video generation logic while adapting to new structure
3. **WebSocket Integration:** Real-time updates for long-running video processing
4. **Python Integration:** Added madmom for professional-grade beat detection
5. **Comprehensive Testing:** Full test coverage to ensure reliability
6. **Metadata-Driven:** Project state stored in JSON for flexibility

## Migration from Original

The implementation preserves all original functionality while adding:
- Web-based interface capabilities
- Multi-project management
- Real-time processing feedback
- Advanced audio analysis
- File upload handling
- YouTube integration improvements

All original shell script logic remains intact, ensuring video quality and processing capabilities are unchanged.

## Future Considerations

1. **Authentication:** Add user management for multi-user deployments
2. **Database:** Replace JSON metadata with proper database for scalability
3. **Queue System:** Add job queue for processing multiple projects
4. **Cloud Storage:** Support for cloud-based project storage
5. **Advanced Analysis:** Additional audio analysis features (tempo detection, etc.)