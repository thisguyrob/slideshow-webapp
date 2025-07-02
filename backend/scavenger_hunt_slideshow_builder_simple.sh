#!/usr/bin/env bash
# ------------------------------------------------------------
# scavenger_hunt_slideshow_builder_simple.sh - Simple & Working
# ------------------------------------------------------------
# Uses pre-rendered temp.mp4 videos with crossfade timing:
# - 1s fade up from black on first slide
# - 5s hold on each slide
# - 1s crossfade between slides
# - 1s fade out on final slide
# - Audio overlay throughout
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920
TARGET_H=1080
FPS=60
VIDEO_CODEC="libx264"
CRF=18
MAX_IMAGES=12

# Timing settings
FADE_IN_DURATION=1
HOLD_DURATION=5
CROSSFADE_DURATION=1
FADE_OUT_DURATION=1

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ $1 is not installed." >&2
    exit 1
  }
}
need_tool ffmpeg
need_tool jq

echo "🎬 Simple Scavenger Hunt Slideshow Builder"
echo "📂 Working directory: $(pwd)"

# Find audio file
AUDIO_FILE=""
if [[ -f "metadata.json" ]]; then
  AUDIO_FILE=$(jq -r '.audioFile // empty' metadata.json 2>/dev/null || true)
fi

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

if [[ -z "$AUDIO_FILE" ]] || [[ ! -f "$AUDIO_FILE" ]]; then
  echo "❌ No audio file found" >&2
  exit 1
fi

echo "🎵 Using audio file: $AUDIO_FILE"

# Read temp videos from slots.json
if [[ ! -f "slots.json" ]]; then
  echo "❌ No slots.json found" >&2
  exit 1
fi

TEMP_VIDEOS=()
while IFS= read -r line; do
  tempVideo=$(echo "$line" | jq -r '.tempVideo // empty')
  if [[ -n "$tempVideo" && -f "$tempVideo" ]]; then
    TEMP_VIDEOS+=("$tempVideo")
    if [[ ${#TEMP_VIDEOS[@]} -ge $MAX_IMAGES ]]; then
      break
    fi
  fi
done < <(jq -c '.[] | select(.tempVideo != null)' slots.json)

NUM_VIDEOS=${#TEMP_VIDEOS[@]}
if [[ $NUM_VIDEOS -eq 0 ]]; then
  echo "❌ No temp videos found" >&2
  exit 1
fi

echo "📹 Found $NUM_VIDEOS temp videos"

# Calculate timing
TOTAL_DURATION=$((FADE_IN_DURATION + NUM_VIDEOS * HOLD_DURATION + (NUM_VIDEOS - 1) * CROSSFADE_DURATION + FADE_OUT_DURATION))
echo "⏱️  Expected duration: ${TOTAL_DURATION}s"

# Create the slideshow using a step-by-step approach
echo "🎞️ Step 1: Creating black frames..."
ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=2:rate=${FPS}" \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
  "temp_black.mp4" 2>/dev/null || { echo "❌ Failed to create black video"; exit 1; }

echo "🎬 Step 2: Building slideshow..."

# Use a much simpler approach - concatenate with overlays
# Create a single long video by processing pairs sequentially

# Start with black fade in to first video
echo "  - Processing fade in..."
ffmpeg -y -i "temp_black.mp4" -i "${TEMP_VIDEOS[0]}" \
  -filter_complex "[0:v][1:v]xfade=transition=fade:duration=${FADE_IN_DURATION}:offset=0[fadedin]" \
  -map "[fadedin]" -t $((FADE_IN_DURATION + HOLD_DURATION + 1)) \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
  "temp_current.mp4" 2>/dev/null || { echo "❌ Failed fade in"; exit 1; }

# Add each subsequent video with crossfade
for ((i=1; i<NUM_VIDEOS; i++)); do
  echo "  - Adding video $((i+1)) of $NUM_VIDEOS..."
  
  # Calculate when to start the crossfade
  CROSSFADE_START=$((FADE_IN_DURATION + (i-1) * (HOLD_DURATION + CROSSFADE_DURATION) + HOLD_DURATION))
  
  # Extend the next video to proper length
  NEXT_VIDEO_DURATION=$((HOLD_DURATION + CROSSFADE_DURATION + 1))
  ffmpeg -y -i "${TEMP_VIDEOS[$i]}" -t $NEXT_VIDEO_DURATION \
    -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
    "temp_next.mp4" 2>/dev/null
  
  # Apply crossfade
  ffmpeg -y -i "temp_current.mp4" -i "temp_next.mp4" \
    -filter_complex "[0:v][1:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${CROSSFADE_START}[crossfaded]" \
    -map "[crossfaded]" -t $((CROSSFADE_START + HOLD_DURATION + CROSSFADE_DURATION + 1)) \
    -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
    "temp_new.mp4" 2>/dev/null || { echo "❌ Failed crossfade $i"; exit 1; }
  
  # Replace current with new
  mv "temp_new.mp4" "temp_current.mp4"
  rm -f "temp_next.mp4"
done

# Add fade out to black
echo "  - Adding fade out..."
FADE_OUT_START=$((FADE_IN_DURATION + (NUM_VIDEOS-1) * (HOLD_DURATION + CROSSFADE_DURATION) + HOLD_DURATION))
ffmpeg -y -i "temp_current.mp4" -i "temp_black.mp4" \
  -filter_complex "[0:v][1:v]xfade=transition=fade:duration=${FADE_OUT_DURATION}:offset=${FADE_OUT_START}[fadedout]" \
  -map "[fadedout]" -t $TOTAL_DURATION \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
  "temp_video_final.mp4" 2>/dev/null || { echo "❌ Failed fade out"; exit 1; }

echo "🎵 Step 3: Adding audio..."
# Add audio with fade out
AUDIO_FADE_START=$((TOTAL_DURATION - FADE_OUT_DURATION))
ffmpeg -y -i "temp_video_final.mp4" -i "$AUDIO_FILE" \
  -c:v copy \
  -af "afade=t=out:st=${AUDIO_FADE_START}:d=${FADE_OUT_DURATION}" \
  -c:a aac -b:a 192k -ar 44100 \
  -map 0:v -map 1:a \
  -shortest \
  -t $TOTAL_DURATION \
  -movflags +faststart \
  "slideshow.mp4" 2>/dev/null || { echo "❌ Failed to add audio"; exit 1; }

# Cleanup
echo "🧹 Cleaning up..."
rm -f temp_*.mp4

if [[ -f "slideshow.mp4" ]]; then
  SIZE=$(du -h slideshow.mp4 | cut -f1)
  ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 slideshow.mp4 2>/dev/null | cut -d. -f1)
  echo "✅ Slideshow created: slideshow.mp4 ($SIZE, ${ACTUAL_DURATION}s)"
  echo "📊 Timing: ${FADE_IN_DURATION}s fade in + ${NUM_VIDEOS}×${HOLD_DURATION}s holds + $((NUM_VIDEOS-1))×${CROSSFADE_DURATION}s crossfades + ${FADE_OUT_DURATION}s fade out"
else
  echo "❌ Failed to create slideshow" >&2
  exit 1
fi