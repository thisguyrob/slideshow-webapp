# Scavenger Hunt Implementation Documentation

## Overview
This document details the complete implementation of the Scavenger Hunt project type for the slideshow webapp. The Scavenger Hunt type provides fixed-timing slideshows with precise audio synchronization, eliminating user control over timing to ensure consistent presentation.

## Key Features
- **Fixed 73-second duration** (1s fade in + 71s content + 1s fade out)
- **Maximum 12 images** enforced
- **Precise timing**: 1s fade up, 5s hold per image, 1s crossfade between images, 1s fade out
- **YouTube audio integration** with start time support
- **Trimmed audio preview** with fade zone visualization
- **No user timing controls** - completely locked timing

## Technical Specifications

### Timing Breakdown
```
Total Duration: 73 seconds
├── Fade in from black: 1 second
├── Image content: 71 seconds
│   ├── Image 1: 5s hold
│   ├── Crossfade 1→2: 1s
│   ├── Image 2: 5s hold
│   ├── Crossfade 2→3: 1s
│   ├── ... (repeat pattern)
│   ├── Image 12: 5s hold
└── Fade out to black: 1 second

Mathematical verification:
- 1s fade in + (12 images × 5s) + (11 crossfades × 1s) + 1s fade out = 73s
```

## Backend Changes

### 1. YouTube Audio Processing (`backend/api/uploads.js`)

#### Modified YouTube Download Pipeline
- **Detection**: Automatically detects Scavenger Hunt projects via `metadata.type`
- **Skips madmom**: No downbeat detection for Scavenger Hunt projects
- **Audio Trimming**: Trims to exactly 73 seconds from user-specified start time

```javascript
// Key changes in youtube-download endpoint:
if (isScavengerHunt) {
  // Step 3: Trim to 73 seconds (yt-dlp already applied start time)
  const trimArgs = [
    '-i', 'song.mp3',
    '-t', '73',           // Duration: 73 seconds
    '-acodec', 'mp3',
    '-ab', '320k',
    '-y',
    'song_trimmed.mp3'
  ];
  
  // Updates metadata with trimming info
  metadata.audioTrimmed = true;
  metadata.audioDuration = 73;
}
```

#### Start Time Handling
- **yt-dlp**: Downloads audio starting from user's specified time
- **No double offset**: Trimming doesn't re-apply start time (fixed duplicate offset bug)

### 2. Project Processing (`backend/api/process.js`)

#### Scavenger Hunt Script Selection
```javascript
// Determines processing script based on project type
let scriptName;
if (projectType === 'Scavenger-Hunt') {
  scriptName = 'process_scavenger_hunt.sh';
} else if (audioType === 'emotional') {
  scriptName = 'process_single_emotional.sh';
} else {
  scriptName = 'process_single_project.sh';
}
```

### 3. Scavenger Hunt Processing Script (`backend/process_scavenger_hunt.sh`)

#### New Dedicated Processing Script
- **Fixed timing**: Hardcoded 73-second duration with precise fade/crossfade timing
- **Maximum images**: Enforces 12-image limit
- **FFmpeg xfade**: Uses professional crossfade transitions
- **60fps output**: Higher frame rate for smooth transitions

```bash
# Key features:
TARGET_W=1920
TARGET_H=1080
FPS=60
MAX_IMAGES=12

# Scavenger Hunt specific timings
FADE_IN_DURATION=1
HOLD_DURATION=5
CROSSFADE_DURATION=1
FADE_OUT_DURATION=1
```

### 4. Project API Updates (`backend/api/projects.js`)

#### Enhanced Project Data Response
```javascript
// Returns both formats for compatibility
res.json({
  ...metadata,                    // Includes audioTrimmed, audioDuration
  images: images.sort(...),
  audio: audioFile ? audioFile.name : null,    // String filename
  audioFile,                      // Object with name/url
  video: videoFile ? videoFile.name : null,    // String filename  
  videoFile,                      // Object with name/url
  youtubeUrl
});
```

## Frontend Changes

### 1. SlideshowViewer Component (`frontend/src/lib/components/SlideshowViewer.svelte`)

#### Scavenger Hunt Mode Detection & Timing
```javascript
// Auto-detects Scavenger Hunt projects
isScavengerHunt = project.type === 'Scavenger-Hunt';

// Enforces 12-image maximum
if (isScavengerHunt && project.images.length > 12) {
  project.images = project.images.slice(0, 12);
}
```

#### Fixed Timing Implementation
- **startScavengerHuntSequence()**: Initiates the 73-second sequence
- **fadeFromBlack()**: 1-second fade in from black overlay
- **holdSlide()**: 5-second hold per image
- **crossfadeToNext()**: 1-second crossfade using overlay technique
- **fadeToBlackAndEnd()**: 1-second fade out to black

#### Audio Integration
```javascript
// Pre-trimmed audio starts from 0 (not user's start time)
audioElement.currentTime = 0;  // Audio is already trimmed correctly
audioElement.play().then(() => {
  fadeAudioIn();  // Synchronized audio fade
});
```

#### User Control Restrictions
- **No manual navigation** during playback for Scavenger Hunt
- **No speed controls** - timing is completely locked
- **Visual indicator**: Shows "Scavenger Hunt Mode" instead of speed selector

### 2. Mini Audio Player (`frontend/src/lib/components/ScavengerHuntAudioPlayer.svelte`)

#### New Component Features
- **Custom player controls**: Play/pause, seek, volume
- **Fade zone visualization**: Progress bar shows fade in/out regions
- **Time display**: Current time / 73 seconds total
- **Educational info**: Explains timing structure to users

```javascript
// Visual fade zone indicators
const fadeInEnd = (1 / duration) * 100;        // 1.37% mark
const fadeOutStart = ((duration - 1) / duration) * 100;  // 98.63% mark

// Progress bar gradient shows:
// - Green zones for fade in/out (0-1s, 72-73s)
// - Light green for main content (1-72s)
```

### 3. Audio Upload Component Updates (`frontend/src/lib/components/ScavengerHuntAudioUpload.svelte`)

#### Smart Component Switching
```javascript
{#if hasAudio && audioFile}
  {#if audioTrimmed}
    <!-- Show mini player for processed audio -->
    <ScavengerHuntAudioPlayer ... />
  {:else}
    <!-- Show basic audio info for unprocessed audio -->
    <audio controls ... />
  {/if}
{:else}
  <!-- YouTube URL upload form -->
{/if}
```

#### Enhanced Props Interface
```typescript
interface Props {
  projectId: string;
  hasAudio: boolean;
  audioFile?: string;
  audioTrimmed?: boolean;    // NEW: Indicates processed audio
  audioDuration?: number;    // NEW: Duration in seconds
  audioOffset?: string;      // NEW: Original start time
}
```

### 4. Scavenger Hunt Page Updates (`frontend/src/routes/scavenger-hunt/[id]/+page.svelte`)

#### Metadata Propagation
```javascript
<ScavengerHuntAudioUpload 
  {projectId} 
  hasAudio={!!project.audio}
  audioFile={project.audio}
  audioTrimmed={project.audioTrimmed}      // NEW
  audioDuration={project.audioDuration}    // NEW
  audioOffset={project.audioOffset}        // NEW
  on:uploaded={handleAudioUploaded}
/>
```

## New Files Created

### 1. Backend Files
- `backend/process_scavenger_hunt.sh` - Dedicated processing script for Scavenger Hunt slideshows

### 2. Frontend Components
- `frontend/src/lib/components/ScavengerHuntAudioPlayer.svelte` - Mini audio player with fade visualization

## Database/Metadata Schema Updates

### Project Metadata Extensions
```json
{
  "type": "Scavenger-Hunt",
  "audioOffset": "0:18",           // User's specified start time
  "audioTrimmed": true,            // NEW: Indicates trimmed audio
  "audioDuration": 73,             // NEW: Duration in seconds
  "audioType": "normal"            // Inherited from existing schema
}
```

## User Experience Flow

### 1. Project Creation
1. User selects "Scavenger Hunt" project type
2. Uploads up to 12 images (enforced)
3. Provides YouTube URL with optional start time

### 2. Audio Processing
1. System downloads audio from specified start time
2. Automatically trims to exactly 73 seconds
3. No madmom processing (skipped for performance)
4. Displays mini audio player with fade visualization

### 3. Preview Experience
1. "Preview Slideshow" tab shows actual timing
2. Fixed 1s fade up, 5s holds, 1s crossfades, 1s fade out
3. Audio plays synchronized from beginning (pre-trimmed)
4. No user controls available during playback

### 4. Final Slideshow Generation
1. Uses dedicated `process_scavenger_hunt.sh` script
2. Creates professional video with exact timing
3. 60fps output for smooth transitions
4. Audio perfectly synchronized with visual transitions

## Technical Benefits

### Performance Improvements
- **No madmom processing**: Faster audio processing for Scavenger Hunt
- **Pre-trimmed audio**: Reduces slideshow generation time
- **Dedicated script**: Optimized for fixed timing requirements

### User Experience Improvements
- **Predictable timing**: Users know exactly what they'll get
- **Professional output**: Consistent, polished results
- **Educational preview**: Users understand the timing structure
- **No configuration errors**: Eliminates timing mistakes

### System Architecture Benefits
- **Type-specific processing**: Clean separation of project type logic
- **Extensible design**: Easy to add new project types
- **Backward compatibility**: Existing project types unaffected

## Bug Fixes Implemented

### 1. Duplicate Start Time Application
**Issue**: Start time was applied twice (yt-dlp + trim step)
**Fix**: Removed start time from trim step since yt-dlp handles it

### 2. Property Name Inconsistency  
**Issue**: Backend returned `audioFile` object, frontend expected `audio` string
**Fix**: Backend now returns both formats for compatibility

### 3. Missing Metadata Propagation
**Issue**: New metadata fields not passed to frontend components
**Fix**: Added `audioTrimmed`, `audioDuration` to API response and component props

## Testing Considerations

### Audio Timing Verification
- Test various start times (0:00, 0:18, 1:30, etc.)
- Verify 73-second duration regardless of source length
- Confirm audio starts at correct position

### Image Handling
- Test with 1-12 images
- Verify 12-image maximum enforcement
- Test crossfade timing with different image counts

### Browser Compatibility
- Test audio playback across browsers
- Verify CSS fade animations work smoothly
- Test fullscreen mode with fixed timing

## Future Enhancement Opportunities

### Potential Improvements
1. **Visual fade preview**: Show fade effects in mini player
2. **Batch processing**: Multiple Scavenger Hunt projects
3. **Custom timing variants**: 60s, 90s versions
4. **Enhanced transitions**: More crossfade options
5. **Mobile optimization**: Touch-friendly controls

### Architecture Extensions
1. **Plugin system**: Modular project type handlers
2. **Timing templates**: Reusable timing configurations
3. **Preview caching**: Faster preview generation
4. **Real-time sync**: Live preview while editing

## Conclusion

The Scavenger Hunt implementation provides a complete, production-ready solution for fixed-timing slideshows with professional audio synchronization. The implementation maintains clean separation of concerns, preserves backward compatibility, and provides an excellent user experience through predictable timing and educational preview features.