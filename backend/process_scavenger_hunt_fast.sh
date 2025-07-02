#!/usr/bin/env bash
# ------------------------------------------------------------
# process_scavenger_hunt_fast.sh - Fast Scavenger Hunt render
# ------------------------------------------------------------
# Uses pre-processed MP4 files for much faster final rendering
# Fixed timing: 1s fade up, 5s hold, 1s crossfade, 1s fade out
# ------------------------------------------------------------
set -euo pipefail

echo "🚀 Script started in directory: $(pwd)"
echo "📂 Files in directory:"
ls -la | head -20

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
FPS=30                # output frame rate (30fps for better performance)
VIDEO_CODEC="libx264"
CRF=18                # visually lossless ~18
MAX_IMAGES=12         # Maximum number of images

# Scavenger Hunt specific timings
FADE_IN_DURATION=1    # Initial fade from black
HOLD_DURATION=5       # Time each image is shown
CROSSFADE_DURATION=1  # Crossfade between images
FADE_OUT_DURATION=1   # Final fade to black

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌  $1 is not installed." >&2
    exit 1
  }
}
need_tool ffmpeg
need_tool jq

echo "🔧 FFmpeg version:"
ffmpeg -version | head -1

echo "▶︎ Processing Scavenger Hunt slideshow using pre-generated videos"

# Find audio file - check metadata first, then fallback to song.mp3
AUDIO_FILE=""
if [[ -f "metadata.json" ]]; then
  # Try to extract audioFile from metadata.json
  AUDIO_FILE=$(jq -r '.audioFile // empty' metadata.json 2>/dev/null || true)
fi

# If no audioFile in metadata, check for song.mp3
if [[ -z "$AUDIO_FILE" ]] || [[ ! -f "$AUDIO_FILE" ]]; then
  if [[ -f "song.mp3" ]]; then
    AUDIO_FILE="song.mp3"
  else
    # Look for any mp3 file
    for mp3 in *.mp3; do
      if [[ -f "$mp3" ]]; then
        AUDIO_FILE="$mp3"
        break
      fi
    done
  fi
fi

if [[ -z "$AUDIO_FILE" ]] || [[ ! -f "$AUDIO_FILE" ]]; then
  echo "❌ No audio file found" >&2
  exit 1
fi

echo "🎵 Using audio file: $AUDIO_FILE"

# Read slots.json to get image order and temp video mappings
if [[ ! -f "slots.json" ]]; then
  echo "❌ No slots.json found" >&2
  exit 1
fi

# Extract slots with temp videos
TEMP_VIDEOS=()
SLOT_IDS=()

while IFS= read -r line; do
  tempVideo=$(echo "$line" | jq -r '.tempVideo // empty')
  slotId=$(echo "$line" | jq -r '.id // empty')
  
  if [[ -n "$tempVideo" && -f "$tempVideo" ]]; then
    TEMP_VIDEOS+=("$tempVideo")
    SLOT_IDS+=("$slotId")
    if [[ ${#TEMP_VIDEOS[@]} -ge $MAX_IMAGES ]]; then
      break
    fi
  fi
done < <(jq -c '.[] | select(.tempVideo != null)' slots.json)

NUM_VIDEOS=${#TEMP_VIDEOS[@]}
if [[ $NUM_VIDEOS -eq 0 ]]; then
  echo "❌ No pre-generated videos found in slots" >&2
  exit 1
fi

echo "📸 Found $NUM_VIDEOS pre-generated videos (max $MAX_IMAGES will be used)"

# Check frame rate of first temp video to match it
if [[ ${#TEMP_VIDEOS[@]} -gt 0 ]]; then
  FIRST_VIDEO="${TEMP_VIDEOS[0]}"
  if [[ -f "$FIRST_VIDEO" ]]; then
    VIDEO_FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$FIRST_VIDEO" 2>/dev/null | cut -d'/' -f1)
    if [[ -n "$VIDEO_FPS" ]]; then
      echo "📹 Detected video frame rate: ${VIDEO_FPS}fps"
      FPS=$VIDEO_FPS
    fi
  fi
fi

# Create black video for fade in/out transitions
echo "🎞️ Creating black video for fade transitions..."
ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=1:rate=${FPS}" \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" \
  -pix_fmt yuv420p \
  "temp_black.mp4"

if [[ ! -f "temp_black.mp4" ]]; then
  echo "❌ Failed to create black video" >&2
  exit 1
fi

# Build the complex filter for concatenation with crossfades
echo "🎬 Building slideshow with crossfades..."

# Build ffmpeg command
CMD=(ffmpeg -y)

# Input: black video for fade in
CMD+=(-i "temp_black.mp4")

# Input: all temp videos
for VIDEO in "${TEMP_VIDEOS[@]}"; do
  CMD+=(-t 7 -i "$VIDEO")  # Limit to 7 seconds (5s + 1s overlap on each side)
done

# Input: black video again for fade out
CMD+=(-i "temp_black.mp4")

# Input: audio file
CMD+=(-i "$AUDIO_FILE")

# Build filter complex
FILTER=""
TOTAL_INPUTS=$((NUM_VIDEOS + 2))  # +2 for black videos

# Create the crossfade chain
# Start with black fade to first image
FILTER="[0:v][1:v]xfade=transition=fade:duration=${FADE_IN_DURATION}:offset=0[v1];"

# Add crossfades between images
for ((i = 1; i < $NUM_VIDEOS; i++)); do
  PREV=$i
  NEXT=$((i + 1))
  OFFSET=$(bc -l <<< "$FADE_IN_DURATION + ($i * ($HOLD_DURATION + $CROSSFADE_DURATION))")
  
  if [[ $i -eq 1 ]]; then
    FILTER+="[v1][${NEXT}:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[v${NEXT}];"
  else
    FILTER+="[v${PREV}][${NEXT}:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[v${NEXT}];"
  fi
done

# Add final fade to black
LAST_VIDEO=$NUM_VIDEOS
# Calculate offset for final fade - need to subtract fade out duration from total
FINAL_OFFSET=$(bc -l <<< "$FADE_IN_DURATION + (($NUM_VIDEOS - 1) * ($HOLD_DURATION + $CROSSFADE_DURATION)) + $HOLD_DURATION")
FILTER+="[v${LAST_VIDEO}][$((NUM_VIDEOS + 1)):v]xfade=transition=fade:duration=${FADE_OUT_DURATION}:offset=${FINAL_OFFSET}[final]"

# Map outputs
CMD+=(-filter_complex "$FILTER")
CMD+=(-map "[final]")
CMD+=(-map "$((TOTAL_INPUTS)):a")

# Output settings
CMD+=(-c:v "$VIDEO_CODEC" -preset slow -crf "$CRF")
CMD+=(-c:a aac -b:a 192k)
CMD+=(-r "$FPS" -pix_fmt yuv420p)
CMD+=(-t 73)  # Fixed 73-second duration
CMD+=(-movflags +faststart)
CMD+=("slideshow.mp4")

echo "🚀 Building with pre-generated videos (much faster!)..."
timeout 300 "${CMD[@]}"

if [[ $? -eq 0 ]]; then
  # Clean up temporary black video
  rm -f temp_black.mp4
  echo "✅ Complete: slideshow.mp4 (73 seconds)"
else
  echo "❌ FFmpeg failed" >&2
  rm -f temp_black.mp4
  exit 1
fi