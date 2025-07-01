# YouTube Audio Processing Implementation

## Overview

The slideshow webapp now supports downloading and processing audio directly from YouTube URLs. This implementation follows the same logic as the `preprocess.zsh` script, providing a complete pipeline for audio extraction, conversion, and beat detection.

## Features

- **YouTube URL Download**: Extract audio from YouTube videos using yt-dlp
- **Start Time Support**: Specify where to begin audio extraction (default: 0:00)
- **Automatic MP3 Conversion**: Ensure audio is in MP3 format using ffmpeg
- **Beat Detection**: Run madmom downbeats detector for slideshow synchronization
- **Comprehensive Logging**: All processing steps are logged to Docker terminal
- **Error Handling**: Detailed error reporting for each processing step

## User Interface

### Audio Upload Component (`AudioUpload.svelte`)

The component now includes:

1. **Upload Mode Selection**: Toggle between file upload and YouTube URL
2. **YouTube URL Input**: Field for entering the YouTube video URL
3. **Start Time Input**: Optional field to specify audio start time (format: mm:ss or hh:mm:ss)
4. **Processing Feedback**: Real-time status updates and step-by-step progress display

#### Usage Example
```
YouTube URL: https://www.youtube.com/watch?v=dQw4w9WgXcQ
Start Time: 1:30 (optional - starts from 1 minute 30 seconds)
```

## Backend Implementation

### API Endpoints

#### POST `/api/upload/:projectId/youtube`
Validates and saves YouTube URL to `audio.txt` file.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=example"
}
```

#### POST `/api/upload/:projectId/youtube-download`
Complete audio processing pipeline.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=example",
  "startTime": "1:30"
}
```

**Response:**
```json
{
  "message": "Audio downloaded and processed successfully",
  "file": {
    "name": "song.mp3",
    "url": "/api/files/projectId/song.mp3"
  },
  "audioOffset": "1:30",
  "downbeatsDetected": true
}
```

### Processing Pipeline

The backend implements a three-step processing pipeline:

#### Step 1: yt-dlp Audio Download
```bash
yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o "song.%(ext)s" [URL]
```

**Features:**
- Extracts audio-only from YouTube videos
- Converts to MP3 format
- Uses highest quality audio (--audio-quality 0)
- Supports start time trimming via ffmpeg post-processing

#### Step 2: ffmpeg Audio Conversion
```bash
ffmpeg -i song.mp3 -acodec mp3 -ab 320k -y song_converted.mp3
```

**Purpose:**
- Ensures consistent MP3 format and quality
- Standardizes audio parameters for downstream processing
- 320kbps bitrate for high quality

#### Step 3: madmom Downbeat Detection
```python
from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor

# Extract downbeat activations
rnn_processor = RNNDownBeatProcessor()
activations = rnn_processor(audio_path)

# Track downbeats
tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=100)
downbeats = tracker(activations)

# Convert to 60fps video frames
downbeat_frames = [round(time * 60) for time, beat_pos in downbeats if beat_pos == 1]
```

**Output:**
Creates `downbeats.json` with structure:
```json
{
  "audio_file": "/absolute/path/to/song.mp3",
  "downbeat_frames": [120, 240, 360, ...]
}
```

## Terminal Logging

All processing steps are logged to the Docker terminal with project-specific prefixes:

```
[project-123] Starting YouTube audio processing pipeline
[project-123] YouTube URL: https://www.youtube.com/watch?v=example
[project-123] Start time: 1:30
[project-123] Step 1: Downloading audio with yt-dlp...
[project-123] yt-dlp: [youtube] Extracting URL: https://www.youtube.com/watch?v=example
[project-123] yt-dlp: [download] 100% of 4.2MiB in 00:02
[project-123] Step 1 completed: Audio downloaded successfully
[project-123] Step 2: Ensuring MP3 format with ffmpeg...
[project-123] ffmpeg: Input #0, mp3, from 'song.mp3'
[project-123] Step 2 completed: Audio converted to MP3
[project-123] Step 3: Running madmom downbeats detector...
[project-123] python: Processing audio file: /path/to/song.mp3
[project-123] python: ✅ Detected 84 downbeats
[project-123] Step 3 completed: Downbeats detection finished
[project-123] All processing steps completed successfully!
```

## File Structure

After successful processing, the project directory contains:

```
projects/[project-id]/
├── audio.txt           # YouTube URL
├── song.mp3           # Processed audio file
├── downbeats.json     # Beat detection results
├── metadata.json      # Updated project metadata
└── [other project files...]
```

## Error Handling

The implementation includes comprehensive error handling for each step:

### Common Errors

1. **Invalid YouTube URL**
   - Validation regex checks for youtube.com, youtu.be, music.youtube.com
   - Returns HTTP 400 with descriptive error message

2. **yt-dlp Download Failure**
   - Network issues, private videos, unavailable content
   - Logs stderr output for debugging

3. **ffmpeg Conversion Failure**
   - Audio codec issues, corrupted downloads
   - Fallback to original file if conversion fails

4. **madmom Processing Failure**
   - Missing Python dependencies, audio format issues
   - Detailed Python error messages in logs

### Error Response Format
```json
{
  "error": "Failed to download audio from YouTube",
  "details": "ERROR: Video unavailable"
}
```

## Dependencies

### System Requirements
- **yt-dlp**: YouTube download utility
- **ffmpeg**: Audio/video processing
- **Python 3.9**: For madmom processing (specific version required)
- **madmom**: Music information retrieval library

### Python Dependencies
```python
madmom>=0.16.1
numpy==1.23.5  # Specific version for madmom compatibility
```

**Important**: madmom requires Python 3.9 or earlier due to compatibility issues with `collections.MutableSequence` in Python 3.10+. The backend is configured to use `python3.9` specifically for downbeat detection processing.

## Integration with Slideshow Processing

The processed audio integrates seamlessly with existing slideshow generation:

1. **Beat-synced Slideshows**: Uses `downbeats.json` for image timing
2. **Emotional Slideshows**: Falls back to crossfade timing if needed
3. **Audio Offset**: Respects start time for synchronization

## Troubleshooting

### Common Issues

1. **No output in terminal**
   - Check Docker container logs: `docker logs [container-name]`
   - Ensure backend server is running

2. **yt-dlp not found**
   - Install yt-dlp: `brew install yt-dlp` (macOS) or `pip install yt-dlp`

3. **Python/madmom errors**
   - Ensure Python 3.9 is installed and available as `python3.9`
   - Verify Python virtual environment setup
   - Check madmom installation: `pip install madmom`
   - If getting MutableSequence import errors, verify Python version is 3.9 or earlier

4. **ffmpeg not found**
   - Install ffmpeg: `brew install ffmpeg` (macOS)

### Debug Mode

For additional debugging, check:
- Backend console output
- Network tab in browser dev tools
- Docker container logs
- Project directory file contents

## Performance Considerations

- **Download time**: Varies by video length and network speed
- **Processing time**: ~30-60 seconds for typical 3-4 minute songs
- **Storage**: MP3 files typically 3-8MB for average songs
- **Memory**: madmom processing requires ~100-200MB RAM

## Future Enhancements

Potential improvements:
- Progress bar with real-time percentage
- Support for audio duration limiting
- Batch processing multiple URLs
- Audio preview before processing
- Custom beat detection parameters