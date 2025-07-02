# Technical Updates Documentation

## Scavenger Hunt Enhancements (2025-07-02)

### 1. Batch Image Upload Feature

#### Overview
Allows users to upload multiple images (up to 12) at once for Scavenger Hunt projects while maintaining individual slot upload capability.

#### Implementation Details

**Frontend Component**: `ScavengerHuntImageGrid.svelte`

```typescript
// State management
let batchUploading = $state(false);
let batchUploadProgress = $state({ current: 0, total: 0 });

// Main batch upload function
async function handleBatchUpload(files: FileList) {
  const uploadedFilenames = getUploadedFilenames();
  const filesToUpload: Array<{file: File, slotId: number}> = [];
  
  // Find empty slots and prepare upload list
  let slotIndex = 0;
  for (let i = 0; i < files.length && filesToUpload.length < 12; i++) {
    const file = files[i];
    
    // Skip duplicate filenames
    if (uploadedFilenames.has(file.name)) {
      console.log(`Skipping duplicate file: ${file.name}`);
      continue;
    }
    
    // Find next empty slot
    while (slotIndex < 12 && imageSlots[slotIndex].image) {
      slotIndex++;
    }
    
    if (slotIndex < 12) {
      filesToUpload.push({ file, slotId: slotIndex + 1 });
      uploadedFilenames.add(file.name);
      slotIndex++;
    }
  }
  
  // Sequential upload with progress tracking
  for (const { file, slotId } of filesToUpload) {
    await handleSlotUpload(slotId, file);
    batchUploadProgress.current++;
  }
}
```

**UI Considerations**:
- Button visibility: `{#if imageSlots.filter(slot => !slot.image).length >= 2}`
- Progress display during upload
- Maintains drag-and-drop functionality

### 2. Audio Replacement Feature

#### Overview
Replaced the destructive "Remove" button with a non-destructive "Replace" workflow for audio tracks.

#### Implementation Details

**Frontend Components**:
- `ScavengerHuntAudioPlayer.svelte`: Dispatch 'replace' event instead of delete
- `ScavengerHuntAudioUpload.svelte`: Show replacement form with cancel option

```typescript
// State for replacement mode
let showReplaceForm = $state(false);

// Replace button handler
function replaceAudio() {
  dispatch('replace');
}

// Cancel replacement
<button onclick={() => showReplaceForm = false}>Cancel</button>
```

### 3. Audio Caching Bug Fix

#### Problem
Browser cached `song.mp3` causing replaced audio to play old content.

#### Solution
Implemented dynamic audio filenames with timestamps.

#### Backend Implementation

**File**: `backend/api/uploads.js`

```javascript
// Generate unique filename
const timestamp = Date.now();
const audioFileName = `audio_${timestamp}.mp3`;

// Track existing audio for cleanup
let existingAudioFile = null;
try {
  const metadata = JSON.parse(await fs.readFile(metadataPath, 'utf-8'));
  if (metadata.audioFile && metadata.audioFile !== 'song.mp3') {
    existingAudioFile = metadata.audioFile;
  }
} catch (err) {}

// After successful upload, cleanup old file
if (existingAudioFile) {
  try {
    await fs.unlink(path.join(projectDir, existingAudioFile));
  } catch (err) {}
}

// Update metadata with new filename
metadata.audioFile = audioFileName;
```

**File**: `backend/api/projects.js`

```javascript
// Prioritize metadata audioFile over file scanning
if (metadata.audioFile && files.includes(metadata.audioFile)) {
  audioFile = {
    name: metadata.audioFile,
    url: `/api/files/${projectId}/${metadata.audioFile}`
  };
}
```

**File**: `backend/process_scavenger_hunt.sh`

```bash
# Dynamic audio file detection
AUDIO_FILE=""
if [[ -f "metadata.json" ]]; then
  # Try jq first
  if command -v jq >/dev/null 2>&1; then
    AUDIO_FILE=$(jq -r '.audioFile // empty' metadata.json 2>/dev/null || true)
  else
    # Fallback to grep/sed
    AUDIO_FILE=$(grep -o '"audioFile"[[:space:]]*:[[:space:]]*"[^"]*"' metadata.json 2>/dev/null | 
                 sed 's/.*"audioFile"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
  fi
fi

# Fallback cascade: metadata -> song.mp3 -> any *.mp3
if [[ -z "$AUDIO_FILE" ]] || [[ ! -f "$AUDIO_FILE" ]]; then
  if [[ -f "song.mp3" ]]; then
    AUDIO_FILE="song.mp3"
  else
    for mp3 in *.mp3; do
      if [[ -f "$mp3" ]]; then
        AUDIO_FILE="$mp3"
        break
      fi
    done
  fi
fi
```

### 4. Metadata Schema Updates

#### New Fields
```json
{
  "audioFile": "audio_1751475115304.mp3",  // Dynamic filename
  "audioTrimmed": true,                     // Scavenger Hunt: always 73s
  "audioDuration": 73,                       // Duration in seconds
  "audioOffset": "0:00"                      // YouTube start time
}
```

### 5. API Changes

#### YouTube Download Endpoint
- Generates unique audio filenames
- Cleans up existing audio files
- Updates metadata with new filename

#### Projects Endpoint
- Checks metadata.audioFile first
- Falls back to file scanning
- Maintains backward compatibility

### 6. Error Handling

#### Duplicate Image Prevention
```javascript
// Check across all slots
const uploadedFilenames = new Set(
  imageSlots
    .filter(slot => slot.filename)
    .map(slot => slot.filename!)
);

if (uploadedFilenames.has(file.name)) {
  alert(`Image "${file.name}" is already uploaded`);
  return;
}
```

#### Audio Length Validation (Scavenger Hunt)
- Minimum 73 seconds required
- Clear error messages with timing suggestions
- Automatic cleanup of invalid files

### 7. Performance Considerations

#### Batch Upload Strategy
- Sequential uploads to avoid server overload
- Individual error handling per file
- Progress tracking for user feedback

#### Caching Prevention
- Timestamp-based filenames force fresh downloads
- Old file cleanup prevents storage bloat
- Metadata tracking ensures consistency

### 8. Testing Checklist

- [ ] Batch upload with mixed file types
- [ ] Batch upload with duplicates
- [ ] Replace audio multiple times
- [ ] Cancel audio replacement
- [ ] Legacy project with song.mp3
- [ ] Project without jq installed
- [ ] Audio file shorter than 73 seconds
- [ ] Batch upload to partially filled grid

### 9. Migration Notes

#### For Existing Projects
1. Legacy `song.mp3` files continue to work
2. First audio replacement will migrate to new format
3. Processing scripts handle both formats

#### Database/Storage Impact
- Slightly increased storage per replacement (until cleanup)
- Metadata file grows by ~50 bytes (audioFile field)
- No database schema changes required