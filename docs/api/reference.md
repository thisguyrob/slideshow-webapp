# Slideshow Web App - API Reference

## Base URL
```
http://localhost:3000/api
```

## Projects API

### List Projects
```http
GET /projects
```

**Response:**
```json
[
  {
    "id": "1704067200000-abc123",
    "name": "My Slideshow",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "updatedAt": "2024-01-01T00:00:00.000Z",
    "hasVideo": false,
    "audioType": "normal"
  }
]
```

### Create Project
```http
POST /projects
```

**Request Body:**
```json
{
  "name": "My New Slideshow"
}
```

**Response:**
```json
{
  "id": "1704067200000-abc123",
  "name": "My New Slideshow",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",
  "audioType": "normal",
  "hasVideo": false
}
```

### Get Project Details
```http
GET /projects/{projectId}
```

**Response:**
```json
{
  "id": "1704067200000-abc123",
  "name": "My Slideshow",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",
  "audioType": "normal",
  "images": [
    {
      "name": "image1.jpg",
      "url": "/api/files/1704067200000-abc123/image1.jpg"
    }
  ],
  "audioFile": {
    "name": "audio.mp3",
    "url": "/api/files/1704067200000-abc123/audio.mp3"
  },
  "videoFile": null,
  "youtubeUrl": "https://www.youtube.com/watch?v=..."
}
```

### Update Project
```http
PUT /projects/{projectId}
```

**Request Body:**
```json
{
  "name": "Updated Name",
  "audioType": "emotional"
}
```

### Delete Project
```http
DELETE /projects/{projectId}
```

### Reorder Images
```http
POST /projects/{projectId}/reorder
```

**Request Body:**
```json
{
  "images": ["image3.jpg", "image1.jpg", "image2.jpg"]
}
```

## Upload API

### Upload Images
```http
POST /upload/{projectId}/images
```

**Request:** Multipart form data
- `images`: Multiple image files (JPEG, PNG, HEIC)

**Response:**
```json
{
  "message": "Images uploaded successfully",
  "files": [
    {
      "name": "image1.jpg",
      "size": 12345,
      "url": "/api/files/1704067200000-abc123/image1.jpg"
    }
  ]
}
```

### Upload Audio
```http
POST /upload/{projectId}/audio
```

**Request:** Multipart form data
- `audio`: Single audio file (MP3, WAV, M4A, AAC)

**Response:**
```json
{
  "message": "Audio uploaded successfully",
  "file": {
    "name": "audio.mp3",
    "size": 54321,
    "url": "/api/files/1704067200000-abc123/audio.mp3"
  }
}
```

### Save YouTube URL
```http
POST /upload/{projectId}/youtube
```

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

**Response:**
```json
{
  "message": "YouTube URL saved successfully",
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

### Download YouTube Audio
```http
POST /upload/{projectId}/youtube-download
```

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "startTime": "00:30",  // Optional: MM:SS format
  "duration": "180"      // Optional: seconds
}
```

**Response:**
```json
{
  "message": "Audio downloaded successfully",
  "file": {
    "name": "audio.mp3",
    "url": "/api/files/1704067200000-abc123/audio.mp3"
  },
  "audioOffset": "00:30"
}
```

### Delete File
```http
DELETE /upload/{projectId}/files/{filename}
```

## Audio Analysis API

### Analyze Audio
```http
POST /analyze/{projectId}/analyze
```

**Request Body:**
```json
{
  "audioType": "normal"  // or "emotional"
}
```

**Response for Normal Mode:**
```json
{
  "type": "beat-synced",
  "audioDuration": 180.5,
  "requiredImages": 45,
  "downbeats": [0.5, 2.1, 3.8, 5.5],
  "averageBeatInterval": 4.0,
  "message": "You need 45 images for this beat-synced slideshow (one per downbeat)"
}
```

**Response for Emotional Mode:**
```json
{
  "type": "emotional",
  "audioDuration": 180.5,
  "requiredImages": 30,
  "imageDisplayTime": 5.2,
  "crossfadeDuration": 3.0,
  "fadeInDuration": 2.0,
  "fadeOutDuration": 3.0,
  "message": "You need 30 images for this 180s emotional slideshow"
}
```

**Fallback Response (no madmom):**
```json
{
  "type": "time-based",
  "audioDuration": 180.5,
  "requiredImages": 90,
  "secondsPerImage": 2.0,
  "estimatedBPM": 120,
  "message": "You need approximately 90 images for this 180s slideshow (estimated without beat detection)",
  "note": "Install Python with madmom for accurate beat detection"
}
```

## Processing API

### Start Processing
```http
POST /process/{projectId}/process
```

**Request Body:**
```json
{
  "audioOffset": "00:30",    // Optional: MM:SS format
  "audioType": "emotional"   // Optional: "normal" or "emotional"
}
```

**Response:**
```json
{
  "message": "Slideshow processing started",
  "projectId": "1704067200000-abc123"
}
```

### Check Status
```http
GET /process/{projectId}/status
```

**Response:**
```json
{
  "projectId": "1704067200000-abc123",
  "isProcessing": true,
  "status": "processing"
}
```

### Cancel Processing
```http
POST /process/{projectId}/cancel
```

**Response:**
```json
{
  "message": "Process cancelled successfully"
}
```

### Download Video
```http
GET /process/{projectId}/download
```

**Response:** File download with proper filename

## WebSocket Events

Connect to WebSocket at: `ws://localhost:3000`

### Progress Updates
```json
{
  "type": "progress",
  "projectId": "1704067200000-abc123",
  "message": "Converting images...",
  "progress": 50,
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

**Progress Values:**
- `null` - General status message
- `0-100` - Percentage complete
- `-1` - Error occurred

## File Access

### Project Files
```http
GET /api/files/{projectId}/{filename}
```

Access uploaded images, audio, and generated videos directly.

## Error Responses

All endpoints return errors in this format:

```json
{
  "error": "Description of the error",
  "details": "Additional error details when available"
}
```

**Common HTTP Status Codes:**
- `400` - Bad Request (validation errors)
- `404` - Not Found (project/file doesn't exist)
- `500` - Internal Server Error

## Rate Limiting

Currently no rate limiting implemented. Consider adding for production use.

## File Size Limits

- Images: 100MB per file
- Audio: 100MB per file
- No limit on number of files per project

## Supported File Types

**Images:**
- JPEG (.jpg, .jpeg)
- PNG (.png)
- HEIC (.heic, .heif)

**Audio:**
- MP3 (.mp3)
- WAV (.wav)
- M4A (.m4a)
- AAC (.aac)

**YouTube:**
- Any yt-dlp compatible URL
- Supports time-based extraction