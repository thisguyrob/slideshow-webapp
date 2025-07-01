# Slideshow Webapp Changes Documentation

## Overview

This document outlines the major changes made to the slideshow webapp, including slideshow timing fixes, video re-render detection, and the complete redesign of the scavenger hunt image upload system.

## Table of Contents

1. [Slideshow Video Timing Fixes](#slideshow-video-timing-fixes)
2. [Video Re-render Detection System](#video-re-render-detection-system)
3. [Scavenger Hunt 12-Slot Image Grid System](#scavenger-hunt-12-slot-image-grid-system)
4. [API Changes](#api-changes)
5. [File Changes Summary](#file-changes-summary)

---

## 1. Slideshow Video Timing Fixes

### Problem
The first slide in slideshow videos was fading up from black for 1 second but then immediately crossfading to the second slide instead of holding for the intended 5 seconds.

### Root Cause
The crossfade offset calculations weren't accounting for the initial 1-second fade-in duration, causing:
- First image: 0-1s fade-in
- **Incorrect**: Crossfade started at 4s → only 3s hold time
- **Correct**: Crossfade should start at 6s → full 5s hold time

### Files Modified

#### 1. `backend/process_single_project.sh`
**Line 108**: Updated crossfade offset calculation
```bash
# Before
OFFSET=$(bc -l <<< "($i * $IMAGE_DURATION) - ($i * $CROSS_DURATION)")

# After  
OFFSET=$(bc -l <<< "1 + ($i * $IMAGE_DURATION) - (($i - 1) * $CROSS_DURATION)")
```

#### 2. `backend/slideshow_builder.sh`
**Line 121**: Updated offset calculation
```bash
# Before
prev=$((i-1)) offset=$((OVERLAP*i))

# After
prev=$((i-1)) offset=$((1 + OVERLAP*i))
```

#### 3. `backend/process_single_emotional.sh`
**Lines 134, 138**: Added `FADE_IN_DURATION` to offset calculations
```bash
# Line 134 - Before
FILTER+="[v0][v1]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=$(bc <<< "$IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION")[vx1];"

# Line 134 - After
FILTER+="[v0][v1]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=$(bc <<< "$FADE_IN_DURATION + $IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION")[vx1];"

# Line 138 - Before
OFFSET=$(bc <<< "$PREV * ($IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION)")

# Line 138 - After
OFFSET=$(bc <<< "$FADE_IN_DURATION + $PREV * ($IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION)")
```

#### 4. `backend/process_scavenger_hunt.sh`
**Line 116**: Already correctly implemented with proper offset calculation
```bash
OFFSET=$((1 + (i-1) * 6))  # Correctly accounts for fade-in
```

### Result
- **First slide**: 1s fade-up + 5s hold + 1s crossfade to second slide
- **Subsequent slides**: 5s display + 1s crossfade
- All transitions now properly account for the initial fade-in duration

---

## 2. Video Re-render Detection System

### Problem
The download video button would always show "Download Video" even when project content had changed since the last video render, potentially serving outdated videos.

### Solution
Implemented timestamp-based change detection that compares when the project was last updated vs. when the video was last processed.

### Files Modified

#### 1. `frontend/my-app/src/routes/project/[id]/+page.svelte`
**Lines 18-34**: Added `isVideoUpToDate()` function
```typescript
function isVideoUpToDate(project: any): boolean {
    // If no video exists, it's not up to date
    if (!project.video) return false;
    
    // If no lastProcessed time, assume video is outdated
    if (!project.lastProcessed) return false;
    
    // If project was updated after last processing, video is outdated
    if (project.updatedAt && project.lastProcessed) {
        const updatedTime = new Date(project.updatedAt).getTime();
        const processedTime = new Date(project.lastProcessed).getTime();
        return processedTime >= updatedTime;
    }
    
    // Default to assuming video is up to date if we have it
    return true;
}
```

**Line 146**: Updated download button condition
```svelte
<!-- Before -->
{:else if project.video}

<!-- After -->
{:else if isVideoUpToDate(project)}
```

**Line 165**: Dynamic button text
```svelte
{project.video ? 'Re-render Slideshow' : 'Generate Slideshow'}
```

#### 2. `frontend/my-app/src/routes/scavenger-hunt/[id]/+page.svelte`
**Line 212**: Updated download condition
```svelte
<!-- Before -->
{:else if hasVideoBeenRendered && project.video}

<!-- After -->
{:else if isVideoUpToDate(project)}
```

**Line 231**: Dynamic button text
```svelte
{project.video ? 'Re-render Slideshow' : 'Download Slideshow'}
```

### Backend Timestamp Management
The system automatically updates timestamps when:
- **Images uploaded/moved/deleted**: `backend/api/uploads.js` (lines 147, 268, 290, 340, 620, 818, 930)
- **Project metadata changes**: `backend/api/projects.js` (lines 93, 212)
- **Video processing completes**: `backend/api/process.js` (line 186)

### User Experience
- **Video up-to-date**: Shows "Download Video" button → direct download
- **Video outdated**: Shows "Re-render Slideshow" button → triggers processing first
- **No video exists**: Shows "Generate Slideshow" button → triggers initial processing

---

## 3. Scavenger Hunt 12-Slot Image Grid System

### Problem
Scavenger hunt projects used the same generic image upload system as other project types, providing no structure for the specific 12-image requirement and allowing duplicate uploads.

### Solution
Complete redesign with a 12-slot grid system, each slot accepting one unique image with comprehensive duplicate prevention.

### New Files Created

#### 1. `frontend/my-app/src/lib/components/ScavengerHuntImageGrid.svelte`
**Complete new component** featuring:

**Key Features:**
- 12 predefined numbered slots in 4×3 grid layout
- Drag & drop support for each slot
- Duplicate prevention across all slots
- Individual slot management (upload/replace/remove)
- Progress tracking with visual indicator
- Responsive design (3×4 on tablet, 2×6 on mobile)

**Props Interface:**
```typescript
interface Props {
    projectId: string;
    slots?: Array<{ id: number; image?: string; filename?: string }>;
    onSlotsUpdate?: (slots: Array<{ id: number; image?: string; filename?: string }>) => void;
}
```

**Core Functions:**
- `handleSlotUpload(slotId, file)`: Upload image to specific slot with duplicate checking
- `removeSlotImage(slotId)`: Remove image from slot
- `getUploadedFilenames()`: Get all uploaded filenames for duplicate detection
- `handleDrop/DragOver/DragLeave`: Drag & drop event handlers

**Styling:**
- CSS Grid layout with responsive breakpoints
- Visual feedback for drag states
- Progress bar showing completion (X of 12 slots filled)
- Hover effects and transitions

### Backend API Changes

#### 1. `backend/api/uploads.js`
**Lines 910-1044**: New slot-based upload endpoint
```javascript
router.post('/:projectId/scavenger-hunt-slot', upload.single('images'), async (req, res) => {
    // Validates project type is 'Scavenger-Hunt'
    // Checks for duplicate filenames across all slots
    // Handles HEIC/HEIF conversion
    // Updates slot data in slots.json
    // Returns processed file information
});
```

**Lines 1046-1079**: New slot data retrieval endpoint
```javascript
router.get('/:projectId/scavenger-hunt-slots', async (req, res) => {
    // Returns current slot configuration
    // Validates project type
    // Creates default empty slots if none exist
});
```

**Key Features:**
- **Slot Data Storage**: Uses `slots.json` within each project directory
- **Duplicate Detection**: Prevents same filename across multiple slots
- **HEIC/HEIF Support**: Automatic conversion for slot uploads
- **Validation**: Ensures only scavenger hunt projects can use slot endpoints
- **Cleanup**: Automatically removes replaced images

### Frontend Integration Changes

#### 1. `frontend/my-app/src/routes/scavenger-hunt/[id]/+page.svelte`

**Import Changes:**
```typescript
// Removed
import ImageUpload from '$lib/components/ImageUpload.svelte';
import ImageGallery from '$lib/components/ImageGallery.svelte';

// Added
import ScavengerHuntImageGrid from '$lib/components/ScavengerHuntImageGrid.svelte';
```

**State Management:**
```typescript
// Added slot state management
let slots = $state<Array<{ id: number; image?: string; filename?: string }>>([]);

// Added slot loading function
async function loadSlots() {
    try {
        const response = await fetch(`http://localhost:3000/api/uploads/${projectId}/scavenger-hunt-slots`);
        if (response.ok) {
            const data = await response.json();
            slots = data.slots;
        }
    } catch (error) {
        console.error('Failed to load slots:', error);
        slots = Array.from({ length: 12 }, (_, i) => ({ id: i + 1 }));
    }
}

// Added slot update handler
function handleSlotsUpdate(updatedSlots) {
    slots = updatedSlots;
    loadProject(); // Reload project to get updated metadata
}
```

**UI Replacement:**
```svelte
<!-- Before: Generic image upload -->
{#if !project.images || project.images.length === 0}
    <ImageUpload {projectId} on:uploaded={handleImagesUploaded} />
{:else}
    <ImageGallery 
        {project} 
        on:updated={handleProjectUpdated}
        on:add-more={handleImagesUploaded}
    />
{/if}

<!-- After: Slot-based grid -->
<div>
    <h2 class="text-lg font-medium text-gray-900 mb-4">Images (12 Slots)</h2>
    <p class="text-sm text-gray-600 mb-6">Upload images to specific slots. Each slot can contain one unique image.</p>
    <ScavengerHuntImageGrid 
        {projectId} 
        {slots}
        onSlotsUpdate={handleSlotsUpdate}
    />
</div>
```

**Condition Updates:**
```svelte
<!-- Updated slideshow conditions to check slots instead of project.images -->
{#if slots.some(slot => slot.image)}
    <SlideshowViewer {project} />

<!-- Updated download button conditions -->
{#if slots.some(slot => slot.image) && project.audio}
    <!-- Show download/render buttons -->
```

### Data Structure

#### Slot Data Format (`slots.json`)
```json
[
  {
    "id": 1,
    "filename": "image1.jpg",
    "image": "/api/uploads/project-id/images/image1.jpg",
    "uploadedAt": "2024-01-01T12:00:00.000Z"
  },
  {
    "id": 2
    // Empty slot - no filename/image properties
  },
  // ... up to id: 12
]
```

### User Experience Flow

1. **Initial State**: 12 empty numbered slots displayed
2. **Upload**: User drags image to slot or clicks to upload
3. **Validation**: System checks for duplicates across all slots
4. **Processing**: HEIC/HEIF files automatically converted
5. **Feedback**: Progress bar updates, slot shows image
6. **Management**: Users can replace or remove images per slot
7. **Completion**: Clear visual indication when all 12 slots filled

---

## 4. API Changes

### New Endpoints

#### Scavenger Hunt Slot Management
```
POST /api/uploads/:projectId/scavenger-hunt-slot
- Upload image to specific slot (1-12)
- Body: FormData with 'images' file and 'slot' number
- Validates project type and prevents duplicates
- Returns: { slot, filename, file }

GET /api/uploads/:projectId/scavenger-hunt-slots  
- Retrieve current slot configuration
- Returns: { slots: Array<SlotData> }
```

### Enhanced Endpoints

#### Project Processing
- **Enhanced**: `POST /api/process/:projectId/process` now updates `lastProcessed` timestamp
- **Enhanced**: All upload endpoints now update `updatedAt` timestamp for change detection

#### File Management
- **Enhanced**: File deletion now properly updates project timestamps
- **Enhanced**: HEIC/HEIF conversion works with slot-based uploads

---

## 5. File Changes Summary

### New Files
```
frontend/my-app/src/lib/components/ScavengerHuntImageGrid.svelte
CHANGES_DOCUMENTATION.md (this file)
```

### Modified Files

#### Backend
```
backend/process_single_project.sh          - Fixed timing calculations (line 108)
backend/slideshow_builder.sh               - Fixed timing calculations (line 121)  
backend/process_single_emotional.sh        - Fixed timing calculations (lines 134, 138)
backend/api/uploads.js                      - Added slot endpoints (lines 910-1079)
```

#### Frontend
```
frontend/my-app/src/routes/project/[id]/+page.svelte           - Added re-render detection
frontend/my-app/src/routes/scavenger-hunt/[id]/+page.svelte    - Complete slot system integration
```

### Configuration Files
```
(No changes to package.json, docker files, or build configuration)
```

---

## Migration Notes

### For Existing Scavenger Hunt Projects
- **Backward Compatibility**: Existing projects will continue to work
- **Automatic Migration**: When opened, existing projects will show empty slots
- **Data Preservation**: Existing images in projects remain accessible
- **Manual Re-upload**: Users may need to re-upload images to specific slots for new functionality

### For New Scavenger Hunt Projects
- **Slot-First Approach**: All uploads go through the 12-slot system
- **Enhanced UX**: Clear visual organization and progress tracking
- **Duplicate Prevention**: Automatic detection and prevention of duplicate uploads

---

## Testing Recommendations

### Slideshow Timing
1. Create project with multiple images and audio
2. Generate slideshow video
3. Verify first slide fades up for 1s, holds for 5s, then crossfades
4. Check all subsequent transitions maintain proper timing

### Re-render Detection  
1. Upload images and audio to project
2. Generate slideshow (download button appears)
3. Upload additional image or change audio
4. Verify button changes to "Re-render Slideshow"
5. Test re-rendering produces updated video

### Scavenger Hunt Slots
1. Create new scavenger hunt project
2. Upload images to different slots (test drag & drop)
3. Attempt to upload same image to different slot (should prevent)
4. Test replace/remove functionality
5. Verify progress tracking updates correctly
6. Generate slideshow with slot-based images

### Cross-browser Testing
- Test drag & drop functionality across browsers
- Verify responsive grid layout on different screen sizes
- Check HEIC/HEIF conversion works in production environment

---

## Performance Considerations

### Frontend
- **Slot State Management**: Efficient reactivity with Svelte 5 `$state`
- **Image Loading**: Lazy loading for slot images
- **Progress Tracking**: Real-time updates without performance impact

### Backend  
- **File Storage**: Slot data stored in lightweight JSON files
- **Duplicate Detection**: Efficient filename checking across slots
- **Image Processing**: Reused existing HEIC/HEIF conversion pipeline

### API Efficiency
- **Targeted Endpoints**: Slot-specific APIs reduce unnecessary data transfer
- **Validation**: Early validation prevents unnecessary processing
- **Cleanup**: Automatic cleanup of replaced images prevents storage bloat

---

## Future Enhancement Opportunities

### Potential Improvements
1. **Drag Between Slots**: Allow dragging images between slots for reordering
2. **Bulk Upload**: Upload multiple images and auto-assign to available slots
3. **Slot Templates**: Predefined slot arrangements for different hunt types
4. **Image Previews**: Thumbnail previews in slot selection
5. **Slot Locking**: Lock specific slots to prevent accidental changes

### Technical Debt
1. **A11y Warnings**: Address accessibility warnings from Svelte build
2. **TypeScript Strictness**: Improve type definitions for slot interfaces
3. **Error Handling**: Enhanced error recovery for network failures
4. **Caching**: Implement slot data caching for improved performance

---

*Documentation generated: January 2025*
*Last updated: After implementation of all three major feature sets*