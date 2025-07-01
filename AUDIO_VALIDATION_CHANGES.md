# Audio Validation Changes for Scavenger Hunt Projects

## Overview
Added audio length validation to ensure Scavenger Hunt projects have sufficient audio duration (minimum 73 seconds) before processing.

## Changes Made

### File Modified: `backend/api/uploads.js`

#### 1. Added Audio Duration Check (Lines 420-443)
- Added `ffprobe` process to check downloaded audio duration before trimming
- Validates that audio is at least 73 seconds long for Scavenger Hunt projects
- Executes after yt-dlp download and ffmpeg conversion, before trimming

#### 2. Enhanced Error Messages (Lines 449-489)
**Two types of validation errors:**

1. **Video too short entirely:**
   - Calculates original video duration by adding downloaded audio + start time offset
   - If total video < 73 seconds: "This video is too short for Scavenger Hunt. The video is only X seconds long, but we need at least 73 seconds. Please choose a different video."

2. **Video long enough, but start time too late:**
   - Calculates maximum valid start time: `originalDuration - 73 seconds`
   - Shows suggested start time: "Start time too late for Scavenger Hunt. With your current start time (X:XX), only Y seconds remain. Try a start time of Z:ZZ or earlier."

#### 3. Cache Cleanup (Lines 491-497)
- Deletes invalid audio file when validation fails
- Prevents yt-dlp from reusing cached files on retry attempts
- Allows fresh downloads with different start times

#### 4. Error Handling (Lines 543-560)
- Added error handling for ffprobe failures
- Graceful fallback if duration cannot be determined

## Technical Details

### Duration Validation Flow
```
1. yt-dlp downloads audio from YouTube (with start time applied)
2. ffmpeg converts to MP3 format
3. ffprobe checks duration of processed audio
4. If < 73 seconds: Calculate original video length and show appropriate error
5. If >= 73 seconds: Proceed with trimming to exactly 73 seconds
```

### Start Time Parsing
- Supports both `mm:ss` and `hh:mm:ss` formats
- Calculates seconds offset for duration calculations
- Used to estimate original video length for error messages

### File Cleanup Strategy
- Only cleans up `song.mp3` when validation fails
- Prevents interference with subsequent download attempts
- Logs cleanup success/failure for debugging

## User Experience Improvements

### Before Changes
- Users would get generic "processing failed" errors
- No guidance on what start times would work
- Cached files prevented retry attempts

### After Changes
- Clear, actionable error messages
- Specific start time suggestions when video is long enough
- Clean retry experience without cache interference
- Distinction between "video too short" vs "start time too late"

## Example Error Messages

**Video too short:**
```
"This video is too short for Scavenger Hunt. The video is only 45 seconds long, but we need at least 73 seconds. Please choose a different video."
```

**Start time too late:**
```
"Start time too late for Scavenger Hunt. With your current start time (2:30), only 65 seconds remain. Try a start time of 1:47 or earlier."
```

## Benefits

1. **Prevents wasted processing time** on videos that won't work
2. **Provides clear user guidance** on what needs to be changed
3. **Enables successful retries** by cleaning up cached files
4. **Maintains 73-second requirement** for slideshow timing consistency