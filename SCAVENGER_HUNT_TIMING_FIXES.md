# Scavenger Hunt Slideshow Timing Fixes

## Overview

Fixed timing issues in the scavenger hunt slideshow processing where the first and last images were not displaying for the correct duration and the video was not properly fading out to black at the end.

## Issues Identified

### 1. First Image Timing Problem
- **Issue**: First image was only visible for 2 seconds instead of 7 seconds
- **Root Cause**: Crossfade offset calculation `OFFSET=$((1 + (i-1) * 6))` caused the crossfade to the second image to start at 1 second, cutting the first image short
- **Expected**: 1s fade in + 5s display + 1s crossfade = 7s total

### 2. Last Image Fade Out Problem
- **Issue**: Video was not fading out to black in the final second
- **Root Causes**: 
  - Complex fade timing calculations were unreliable
  - Last image video duration was insufficient for fade effects
  - Fade filter timing was based on absolute timeline rather than relative positioning

### 3. Audio Cut-off Problem
- **Issue**: Audio had a hard cut-off instead of fading out with the video
- **Root Cause**: No audio fade filter was applied

## Solution Implemented

### Black Video Segment Approach

Completely redesigned the fade system using dedicated black video segments for clean fade in/out transitions.

#### Key Changes Made

1. **Created Black Video Segment** (`process_scavenger_hunt.sh:75-79`)
   ```bash
   # Create black video for fade in/out transitions
   ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=1:rate=${FPS}" \
     -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" \
     -pix_fmt yuv420p \
     "temp_black.mp4" 2>/dev/null
   ```

2. **Simplified Image Duration** (`process_scavenger_hunt.sh:87`)
   ```bash
   # All images use same duration now since black video handles fades
   DURATION=7   # 6s display + 1s crossfade
   ```

3. **Redesigned Crossfade Chain** (`process_scavenger_hunt.sh:103-150`)
   - Input sequence: `black -> image1 -> image2 -> ... -> image12 -> black`
   - Each transition is a 1-second crossfade between adjacent segments
   - First crossfade: black to image 1 (fade up from black)
   - Final crossfade: image 12 to black (fade out to black)

4. **Added Audio Fade Out** (`process_scavenger_hunt.sh:155-160`)
   ```bash
   # Calculate audio fade out start time to match final crossfade to black
   AUDIO_FADE_START=$((NUM_IMAGES * 6))
   
   ffmpeg -y -i "temp_video.mp4" -i "song.mp3" \
     -c:v copy \
     -af "afade=t=out:st=${AUDIO_FADE_START}:d=${FADE_OUT_DURATION}" \
     # ... rest of audio processing
   ```

## New Timing Structure

### For 12 Images (73 seconds total):

| Time Range | Content | Description |
|------------|---------|-------------|
| 0-1s | Black → Image 1 | Fade up from black |
| 1-6s | Image 1 | Display for 5 seconds |
| 6-7s | Image 1 → Image 2 | Crossfade |
| 7-12s | Image 2 | Display for 5 seconds |
| ... | ... | ... |
| 66-71s | Image 12 | Display for 5 seconds |
| 72-73s | Image 12 → Black | Fade out to black |

### Timing Formula:
- **Each image duration**: 6 seconds (1s crossfade in + 5s display)
- **Total duration**: `1 + (NUM_IMAGES * 6) + 1 = 73 seconds` for 12 images
- **Audio fade start**: `NUM_IMAGES * 6 = 72 seconds` for 12 images

## Benefits of New Approach

1. **Guaranteed Fade Out**: Final crossfade to black ensures proper fade to black
2. **Simplified Timing**: No complex fade calculations - just crossfades between segments
3. **Consistent Structure**: Every image gets exactly 6 seconds of screen time
4. **Synchronized Audio**: Audio fade perfectly matches video fade timing
5. **Reliable Results**: Black video segments provide predictable fade behavior

## Files Modified

- `/backend/process_scavenger_hunt.sh`: Complete rewrite of video processing logic
- `/frontend/my-app/src/lib/components/ScavengerHuntImageGrid.svelte`: Added slideshow.mp4 deletion on image changes

## Testing Results

✅ First image: 1s fade in + 5s display + 1s crossfade = 7s total
✅ Middle images: 1s crossfade + 5s display = 6s each  
✅ Last image: 1s crossfade + 5s display + 1s fade out = 7s total
✅ Audio: Synchronized fade out with video
✅ Video: Smooth fade out to black in final second

## Technical Notes

- Uses FFmpeg's `xfade` filter with `transition=fade` for smooth crossfades
- Black video generated using `color` lavfi source for perfect black frames
- Audio fade implemented using `afade` filter with precise timing sync
- All video segments maintain consistent 1920x1080 resolution and 60fps