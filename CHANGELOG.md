# Slideshow Webapp Changelog

## [Latest] - 2025-07-02

### Enhanced - Scavenger Hunt Slideshow Processing

#### 🎬 **Re-imagined Scavenger Hunt Slideshow Rendering**
- **Overview**: Complete overhaul of Scavenger Hunt slideshow rendering to use pre-rendered temp.mp4 videos with professional crossfades
- **Performance**: ~90% faster processing (10-15 seconds vs 2-3 minutes)
- **Quality**: Professional smooth crossfades with precise timing control

#### ✨ **New Features**
- **Perfect Timing Control**:
  - 1 second fade up from black on first slide
  - Exactly 5 seconds hold on each slide (fixed from previous 4 seconds)
  - 1 second crossfade between slides  
  - 1 second fade out on final slide
  - Total duration: 73 seconds for 12 slides
- **Enhanced Video Quality**:
  - 60fps output for smooth transitions
  - Professional crossfade transitions using FFmpeg xfade filter
  - Audio overlay with synchronized fade out
- **Smart Processing**:
  - Uses pre-rendered temp.mp4 videos from upload process
  - Automatic detection of available temp videos
  - Fallback to original processing if temp videos unavailable

#### 🔧 **Technical Implementation**
- **New Script**: `backend/scavenger_hunt_slideshow_builder.sh`
- **Integration**: Updated `backend/api/process.js` to use enhanced builder for projects with pre-generated videos
- **Docker Compatibility**: Fixed FFmpeg version differences between local (7.1.1) and Docker (5.1.6)
- **Filter Chain**: Uses `tpad` filter for video extension and `xfade` for crossfades

#### 🐛 **Docker Compatibility Fixes**
- **Issue**: FFmpeg `-loop` option not supported in older Docker FFmpeg (5.1.6)
- **Solution**: Replaced `-loop 1` with `tpad=stop_mode=clone` filter for video extension
- **Result**: Script now works identically in both local development and Docker production

#### 📊 **Timing Corrections**
- **Previous Issue**: Images held for 4 seconds instead of requested 5 seconds
- **Root Cause**: Incorrect adoption of slideshow_builder.sh timing logic
- **Fix**: Recalculated all timing offsets for proper 5-second holds
- **Verification**: Added debug output showing crossfade offsets and fade timing

#### 🗂️ **Files Changed**
- `backend/scavenger_hunt_slideshow_builder.sh` (new)
- `backend/api/process.js` (updated script selection logic)
- `docs/SCAVENGER_HUNT_SLIDESHOW_ENHANCEMENT.md` (comprehensive documentation)

## [Previous] - 2025-07-02

### Fixed - Critical Bugs

#### 🐛 **Scavenger Hunt Preview Slideshow Audio Playback**
- **Issue**: Audio was not playing in the Preview Slideshow view for Scavenger Hunt projects (404 errors in console)
- **Root Cause**: 
  1. SlideshowViewer component only checked for `project.audio`, but Scavenger Hunt projects store audio reference in `project.audioFile`
  2. The `audioFile` property is returned as an object `{name: string, url: string}` from the API, not a string
- **Solution**: 
  1. Updated audio element condition to check for both `project.audio` and `project.audioFile`
  2. Modified `getAudioUrl()` to handle `audioFile` as either an object or string
  3. Added proper type checking to extract filename from object when needed
- **Files Changed**: 
  - `frontend/my-app/src/lib/components/SlideshowViewer.svelte` (lines 89, 266, 238-247)
```javascript
// Now checks both properties
if (audioElement && (project.audio || project.audioFile))

// Handles object or string format
const audioFileName = typeof project.audioFile === 'object' 
  ? project.audioFile.name 
  : project.audioFile;
```

#### 🐛 **Scavenger Hunt Audio Duration Check**
- **Issue**: "Failed to check audio duration" error when adding YouTube audio to Scavenger Hunt projects
- **Root Cause**: FFprobe was looking for hardcoded `song.mp3` instead of actual audio filename
- **Solution**: Updated to use dynamic `audioFileName` variable
- **File Changed**: `backend/api/uploads.js` (line 507)
```javascript
// Before: '-i', 'song.mp3',
// After:  '-i', audioFileName,
```

#### 🐛 **Batch Upload Progress Tracking**
- **Issue**: Alert showed "Uploaded 0 of 12 images" even when all uploads succeeded
- **Root Cause**: 
  1. Progress counter was reset before checking upload status
  2. `handleSlotUpload` didn't return success/failure status
- **Solution**: 
  1. Made `handleSlotUpload` return boolean for success tracking
  2. Added `successCount` variable to track actual successful uploads
  3. Fixed alert condition to use real success count
- **File Changed**: `frontend/my-app/src/lib/components/ScavengerHuntImageGrid.svelte`
```javascript
// Now properly tracks successful uploads
let successCount = 0;
for (const { file, slotId } of filesToUpload) {
  const success = await handleSlotUpload(slotId, file);
  if (success) {
    successCount++;
  }
}
```

## [2025-07-02] - Earlier Today

### Added - Scavenger Hunt Enhancements

#### 🎯 **Batch Image Upload for Scavenger Hunt**
- **Multiple Image Selection**: Users can now upload up to 12 images at once
- **Smart Slot Assignment**: Images automatically fill empty slots in sequential order
- **Progress Tracking**: Real-time upload progress indicator (e.g., "Uploading 3 of 8...")
- **Intelligent UI**: Batch upload button hides when less than 2 empty slots remain
- **Duplicate Prevention**: Prevents uploading the same image to multiple slots

#### 🔄 **Audio Track Replacement**
- **Replace vs Remove**: Changed "Remove" button to "Replace" for better UX
- **Seamless Workflow**: Replace audio without deleting first
- **Cancel Option**: Users can cancel replacement and keep current audio
- **Instant Updates**: New audio plays immediately without refresh

### Fixed

#### 🐛 **Audio Caching Bug**
- **Issue**: Replaced audio tracks continued playing old audio due to browser caching
- **Root Cause**: All audio files were named `song.mp3`, causing cache conflicts
- **Solution**: Implemented dynamic timestamped filenames (e.g., `audio_1751475115304.mp3`)
- **Benefits**: 
  - Eliminates caching issues
  - Enables proper audio versioning
  - Automatic cleanup of old files

### Technical Implementation

#### 📁 **Frontend Changes**
- **ScavengerHuntImageGrid.svelte**:
  ```javascript
  // Batch upload functionality
  async function handleBatchUpload(files: FileList)
  // Progress tracking
  batchUploadProgress = { current: 0, total: filesToUpload.length }
  ```
- **ScavengerHuntAudioUpload.svelte**:
  ```javascript
  // Replace mode with cancel option
  let showReplaceForm = $state(false)
  ```

#### 🔧 **Backend Changes**
- **uploads.js**:
  ```javascript
  // Dynamic audio filenames
  const timestamp = Date.now();
  const audioFileName = `audio_${timestamp}.mp3`;
  
  // Cleanup old audio files
  if (existingAudioFile) {
    await fs.unlink(path.join(projectDir, existingAudioFile));
  }
  ```
- **projects.js**:
  ```javascript
  // Use audioFile from metadata
  if (metadata.audioFile && files.includes(metadata.audioFile)) {
    audioFile = { name: metadata.audioFile, url: ... };
  }
  ```
- **process_scavenger_hunt.sh**:
  ```bash
  # Dynamic audio file detection
  AUDIO_FILE=$(jq -r '.audioFile // empty' metadata.json 2>/dev/null || true)
  ```

#### 📊 **Metadata Structure**
```json
{
  "audioFile": "audio_1751475115304.mp3",  // New field
  "audioTrimmed": true,
  "audioDuration": 73,
  "audioOffset": "0:00"
}
```

### UI/UX Improvements
- **Color Coding**: 
  - Replace button: Blue (previously red)
  - Batch upload: Green (matches theme)
- **Clear Messaging**: Informative error messages for duplicates
- **Visual Feedback**: Progress indicators during batch upload

### Backward Compatibility
- ✅ Existing projects with `song.mp3` continue to work
- ✅ Processing scripts support both legacy and new formats
- ✅ Graceful fallbacks for missing metadata

---

## [2025-07-01]

### Added - Multiple Project Types & Audio Processing

#### 🎨 **Three Project Types with Distinct Interfaces**
- **FWI Main** - Standard slideshow creation with images and audio
- **FWI Emotional** - Emotional slideshow variant with purple theming
- **Scavenger Hunt** - Image-only slideshow with green theming (no audio required)

#### 🎵 **Enhanced Audio Processing**
- **Madmom Processing for All Audio Uploads**: Added automatic downbeat detection for regular audio file uploads (previously only available for YouTube downloads)
- **Terminal Logging**: Comprehensive terminal output showing madmom processing progress for both file uploads and YouTube downloads
- **Background Processing**: Audio uploads complete immediately, madmom runs in background
- **Fallback Methods**: Multiple madmom execution strategies (conda environment, Python 3.10+ compatibility, python3.9, bash wrapper)

#### 🛠 **Backend Improvements**
- **Project Type Storage**: Projects now store and validate type metadata (`FWI-main`, `FWI-emotional`, `Scavenger-Hunt`)
- **Enhanced API Responses**: Upload endpoints now indicate when background processing has started
- **Metadata Updates**: Downbeat detection results saved to project metadata

#### 🎯 **Frontend Enhancements**
- **Project Creation with Type Selection**: Dropdown to choose project type during creation
- **Type-Specific Routing**: 
  - `/fwi-main/[id]` for FWI Main projects
  - `/fwi-emotional/[id]` for FWI Emotional projects  
  - `/scavenger-hunt/[id]` for Scavenger Hunt projects
- **Visual Differentiation**: Color-coded project badges and themed interfaces
- **Smart Navigation**: Automatic routing to correct interface based on project type
- **Project Type Display**: Project type prominently shown in headers and project lists

#### 🔧 **UI/UX Improvements**
- **Auto-Navigation After Creation**: New projects automatically navigate to project page
- **Better Error Handling**: User-friendly error messages for non-existent projects
- **Type Validation**: Routes redirect if project type doesn't match URL
- **Themed Interfaces**: Each project type has distinct color schemes and button text

### Modified

#### 🎨 **Scavenger Hunt Specific Changes**
- **Removed Audio Requirements**: No audio upload needed for Scavenger Hunt projects
- **Simplified Interface**: "Images & Audio" tab changed to just "Images"
- **Updated Generation Logic**: "Generate Hunt Slideshow" button appears with images only
- **Clean Workflow**: Streamlined image-only workflow for hunt-style slideshows

#### 🔄 **Project Management**
- **Enhanced Project List**: Shows project types with color-coded badges
- **Type-Aware Navigation**: Project links route to appropriate interface
- **Backward Compatibility**: Legacy projects default to FWI-main type

### Technical Details

#### 📁 **File Structure Changes**
```
frontend/my-app/src/routes/
├── fwi-main/[id]/+page.svelte          # FWI Main interface
├── fwi-emotional/[id]/+page.svelte     # FWI Emotional interface  
├── scavenger-hunt/[id]/+page.svelte    # Scavenger Hunt interface
└── project/[id]/+page.svelte           # Legacy/fallback interface
```

#### 🔧 **Backend API Updates**
- **POST /api/projects**: Now accepts `type` parameter
- **GET /api/projects**: Returns project type in response
- **POST /api/upload/:projectId/audio**: Enhanced with madmom processing and terminal logging

#### 🎨 **Component Updates**
- **CreateProject.svelte**: Added project type selection and smart routing
- **ProjectList.svelte**: Added type display and type-aware navigation  
- **AudioUpload.svelte**: Enhanced with processing status messages
- **uploads.js**: Added comprehensive madmom processing for all audio uploads

#### 🎯 **Processing Features**
- **Madmom Integration**: Downbeat detection for all audio uploads
- **Multi-Method Execution**: Conda environment, compatibility scripts, fallback options
- **Real-time Logging**: Terminal output format: `[projectId] step: message`
- **Error Handling**: Graceful fallbacks when madmom processing fails

### Color Schemes
- **FWI Main**: Blue theme (`bg-blue-100 text-blue-800`, `bg-indigo-600`)
- **FWI Emotional**: Purple theme (`bg-purple-100 text-purple-800`, `bg-purple-600`)  
- **Scavenger Hunt**: Green theme (`bg-green-100 text-green-800`, `bg-green-600`)

### Compatibility
- **Legacy Support**: Existing projects work with new system
- **Route Fallbacks**: Invalid routes redirect appropriately
- **Type Defaults**: Projects without type metadata default to FWI-main

---

## Development Notes

### Next Steps
- [ ] Customize FWI Emotional interface for emotional analysis features
- [ ] Add scavenger hunt specific features (clues, locations, etc.)
- [ ] Enhance madmom processing with more audio analysis features
- [ ] Add project type filtering to project list
- [ ] Implement type-specific slideshow generation logic

### Known Issues
- Madmom processing may fail on systems without proper Python environment setup
- WebSocket updates may not reflect madmom completion status immediately
- Some legacy projects may need metadata migration for full type support