#!/usr/bin/env bash
# ------------------------------------------------------------
# process_scavenger_hunt.sh - Process Scavenger Hunt projects
# ------------------------------------------------------------
# Fixed timing: 1s fade up, 5s hold, 1s crossfade, 1s fade out
# Maximum 12 images, 73 seconds total duration
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
FPS=60                # output frame rate (60fps for smooth transitions)
VIDEO_CODEC="libx264"
CRF=18                # visually lossless ~18
PAD_COLOR="black"     # padding color

# Scavenger Hunt specific timings
FADE_IN_DURATION=1    # Initial fade from black
HOLD_DURATION=5       # Time each image is shown
CROSSFADE_DURATION=1  # Crossfade between images
FADE_OUT_DURATION=1   # Final fade to black
MAX_IMAGES=12         # Maximum number of images

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌  $1 is not installed." >&2
    exit 1
  }
}
need_tool ffmpeg

echo "▶︎ Processing Scavenger Hunt slideshow (fixed 73-second duration)"

# Find audio file - check metadata first, then fallback to song.mp3
AUDIO_FILE=""
if [[ -f "metadata.json" ]]; then
  # Try to extract audioFile from metadata.json
  if command -v jq >/dev/null 2>&1; then
    AUDIO_FILE=$(jq -r '.audioFile // empty' metadata.json 2>/dev/null || true)
  else
    # Fallback method using grep
    AUDIO_FILE=$(grep -o '"audioFile"[[:space:]]*:[[:space:]]*"[^"]*"' metadata.json 2>/dev/null | sed 's/.*"audioFile"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
  fi
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

# Convert HEIC images if on Linux (using heif-convert)
if command -v heif-convert >/dev/null 2>&1; then
  for HEIC in *.heic *.HEIC *.heif *.HEIF; do
    if [[ -f "$HEIC" ]]; then
      BASE="${HEIC%.*}"
      echo "🔄 Converting $HEIC to ${BASE}.jpg..."
      heif-convert "$HEIC" "${BASE}.jpg" || echo "⚠️  Failed to convert $HEIC"
    fi
  done
fi

# Collect images based on slots.json order if it exists
IMAGES=()
if [[ -f "slots.json" ]]; then
  echo "📋 Reading image order from slots.json..."
  # Extract filenames from slots.json in order
  # Using jq if available, otherwise fallback to grep/sed
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r filename; do
      if [[ -n "$filename" && -f "$filename" ]]; then
        IMAGES+=("$filename")
      fi
    done < <(jq -r '.[] | select(.filename != null) | .filename' slots.json)
  else
    # Fallback method using grep and sed
    while IFS= read -r line; do
      if [[ "$line" =~ \"filename\":\ *\"([^\"]+)\" ]]; then
        filename="${BASH_REMATCH[1]}"
        if [[ -f "$filename" ]]; then
          IMAGES+=("$filename")
        fi
      fi
    done < slots.json
  fi
else
  # Fallback to collecting images by extension if no slots.json
  echo "⚠️  No slots.json found, using default image order..."
  for EXT in jpg JPG jpeg JPEG png PNG; do
    for IMG in *.$EXT; do
      if [[ -f "$IMG" ]]; then
        IMAGES+=("$IMG")
        if [[ ${#IMAGES[@]} -ge $MAX_IMAGES ]]; then
          break 2
        fi
      fi
    done
  done
fi

NUM_IMAGES=${#IMAGES[@]}
if [[ $NUM_IMAGES -eq 0 ]]; then
  echo "❌ No images found" >&2
  exit 1
fi

echo "📸 Found $NUM_IMAGES images (max $MAX_IMAGES will be used)"

# Create black video for fade in/out transitions
echo "🎞️ Creating black video for fade transitions..."
ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=1:rate=${FPS}" \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" \
  -pix_fmt yuv420p \
  "temp_black.mp4" 2>/dev/null

# Create individual image videos with proper duration
echo "🎞️ Creating individual image segments..."
for i in "${!IMAGES[@]}"; do
  IMG="${IMAGES[$i]}"
  
  # All images use same duration now since black video handles fades
  DURATION=7   # 6s display + 1s crossfade
  
  ffmpeg -y -loop 1 -i "$IMG" -t $DURATION \
    -vf "scale=w=${TARGET_W}:h=${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=${PAD_COLOR},setsar=1,fps=${FPS}" \
    -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" \
    -pix_fmt yuv420p \
    "temp_image_${i}.mp4" 2>/dev/null
done

# Build the filter complex for concatenation with crossfades
echo "🎬 Building slideshow with crossfades..."

# Build xfade chain with black video for proper fade in/out
FILTER=""

# Build FFmpeg command with all inputs: black + images + black
FFMPEG_CMD=(ffmpeg -y)

# Add black video input first
FFMPEG_CMD+=(-i "temp_black.mp4")

# Add all image inputs
for ((i=0; i<NUM_IMAGES; i++)); do
  FFMPEG_CMD+=(-i "temp_image_${i}.mp4")
done

# Add black video input last
FFMPEG_CMD+=(-i "temp_black.mp4")

# Create crossfade chain: black -> images -> black
# First crossfade: black to first image at offset 0
FILTER="[0:v][1:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=0[v1];"

# Crossfades between images
for ((i=1; i<NUM_IMAGES; i++)); do
  PREV="v${i}"
  CURRENT=$((i+1))  # +1 because black video is input 0
  
  # Offset: 6 seconds per transition (5s hold + 1s crossfade)
  OFFSET=$((i * 6))
  
  FILTER+="[${PREV}][${CURRENT}:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[v$((i+1))];"
done

# Final crossfade: last image to black
LAST_IMAGE_INDEX=$((NUM_IMAGES))
BLACK_INPUT_INDEX=$((NUM_IMAGES + 1))
FINAL_OFFSET=$((NUM_IMAGES * 6))

FILTER+="[v${LAST_IMAGE_INDEX}][${BLACK_INPUT_INDEX}:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${FINAL_OFFSET}[vout]"

# Add filter and output
FFMPEG_CMD+=(
  -filter_complex "$FILTER"
  -map "[vout]"
  -c:v "$VIDEO_CODEC"
  -preset slow
  -crf "$CRF"
  -pix_fmt yuv420p
  "temp_video.mp4"
)

# Execute
"${FFMPEG_CMD[@]}" 2>/dev/null

# Add audio to the video with fade out
echo "🎵 Adding audio track with fade out..."

# Calculate audio fade out start time to match final crossfade to black
AUDIO_FADE_START=$((NUM_IMAGES * 6))

ffmpeg -y -i "temp_video.mp4" -i "$AUDIO_FILE" \
  -c:v copy \
  -af "afade=t=out:st=${AUDIO_FADE_START}:d=${FADE_OUT_DURATION}" \
  -c:a aac -b:a 192k -ar 44100 \
  -map 0:v -map 1:a \
  -shortest \
  -movflags +faststart \
  "slideshow.mp4" 2>/dev/null

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -f temp_image_*.mp4 temp_video.mp4 temp_black.mp4

if [[ -f "slideshow.mp4" ]]; then
  SIZE=$(du -h slideshow.mp4 | cut -f1)
  DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 slideshow.mp4 2>/dev/null | cut -d. -f1)
  echo "✅ Scavenger Hunt slideshow created: slideshow.mp4 ($SIZE, ${DURATION}s)"
  echo "📊 Timing: ${FADE_IN_DURATION}s fade in + ${NUM_IMAGES} images × ${HOLD_DURATION}s + $((NUM_IMAGES-1)) × ${CROSSFADE_DURATION}s crossfade + ${FADE_OUT_DURATION}s fade out"
else
  echo "❌ Failed to create slideshow" >&2
  exit 1
fi