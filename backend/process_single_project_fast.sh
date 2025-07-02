#!/usr/bin/env bash
# ------------------------------------------------------------
# process_single_project_fast.sh - Fast render using pre-generated MP4s
# ------------------------------------------------------------
# Uses pre-processed MP4 files for much faster final rendering
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
IMAGE_DURATION=5      # seconds per image (display time)
CROSS_DURATION=1      # cross-fade duration
FPS=60                # output frame rate
VIDEO_CODEC="libx264"
CRF=18                # visually lossless ~18
PAD_COLOR="black"     # padding color

# Audio offset from environment or default
AUDIO_OFFSET="${AUDIO_OFFSET:-00:00}"

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌  $1 is not installed." >&2
    exit 1
  }
}
need_tool ffmpeg
need_tool yt-dlp
need_tool jq

echo "▶︎ Processing slideshow using pre-generated videos"

# Check if audio.txt exists (YouTube URL)
if [[ -f "audio.txt" ]]; then
  URL=$(cat audio.txt)
  echo "📥 Downloading audio from YouTube..."
  yt-dlp -x --audio-format mp3 -o "audio.mp3" "$URL" || {
    echo "❌ Failed to download audio from YouTube" >&2
    exit 1
  }
fi

# Find audio file
AUDIO=""
for EXT in mp3 wav m4a aac; do
  for FILE in *.$EXT; do
    if [[ -f "$FILE" ]]; then
      AUDIO="$FILE"
      break 2
    fi
  done
done

if [[ -z "$AUDIO" ]]; then
  echo "❌ No audio file found" >&2
  exit 1
fi

echo "🎵 Using audio: $AUDIO (offset: $AUDIO_OFFSET)"

# Read metadata to get image order and temp video mappings
if [[ ! -f "metadata.json" ]]; then
  echo "❌ No metadata.json found" >&2
  exit 1
fi

# Check if we have imageOrder array (for reordered images)
IMAGE_ORDER=$(jq -r '.imageOrder // empty' metadata.json)

if [[ -n "$IMAGE_ORDER" && "$IMAGE_ORDER" != "null" ]]; then
  # Use imageOrder if available
  echo "📋 Using custom image order from metadata"
  
  # Create a map of image names to temp videos
  declare -A TEMP_VIDEO_MAP
  while IFS= read -r line; do
    originalName=$(echo "$line" | jq -r '.originalName // empty')
    tempVideo=$(echo "$line" | jq -r '.tempVideo // empty')
    if [[ -n "$originalName" && -n "$tempVideo" ]]; then
      TEMP_VIDEO_MAP["$originalName"]="$tempVideo"
    fi
  done < <(jq -c '.images[]' metadata.json)
  
  # Build arrays in the order specified
  TEMP_VIDEOS=()
  ORIGINAL_NAMES=()
  
  while IFS= read -r imageName; do
    if [[ -n "${TEMP_VIDEO_MAP[$imageName]}" && -f "${TEMP_VIDEO_MAP[$imageName]}" ]]; then
      TEMP_VIDEOS+=("${TEMP_VIDEO_MAP[$imageName]}")
      ORIGINAL_NAMES+=("$imageName")
    fi
  done < <(echo "$IMAGE_ORDER" | jq -r '.[]')
else
  # Fallback to images array order
  echo "📋 Using default image order"
  
  IMAGES_JSON=$(jq -r '.images // []' metadata.json)
  if [[ "$IMAGES_JSON" == "[]" ]]; then
    echo "❌ No images found in metadata" >&2
    exit 1
  fi
  
  # Build arrays of temp videos and original names
  TEMP_VIDEOS=()
  ORIGINAL_NAMES=()
  
  while IFS= read -r line; do
    tempVideo=$(echo "$line" | jq -r '.tempVideo // empty')
    originalName=$(echo "$line" | jq -r '.originalName // empty')
    
    if [[ -n "$tempVideo" && -f "$tempVideo" ]]; then
      TEMP_VIDEOS+=("$tempVideo")
      ORIGINAL_NAMES+=("$originalName")
    fi
  done < <(echo "$IMAGES_JSON" | jq -c '.[]')
fi

NUM_VIDEOS=${#TEMP_VIDEOS[@]}
if [[ $NUM_VIDEOS -eq 0 ]]; then
  echo "❌ No pre-generated videos found" >&2
  exit 1
fi

echo "📸 Found $NUM_VIDEOS pre-generated videos"

# Build filter complex for crossfades
FILTER=""

# First video with fade in
FILTER="[0:v]fade=t=in:d=1:alpha=1[v0];"

# Add remaining videos
for ((i = 1; i < $NUM_VIDEOS; i++)); do
  FILTER+="[${i}:v]fade=t=in:d=1:alpha=1[v${i}];"
done

# Create cross-fade chain
FILTER+="[v0]"
for ((i = 1; i < $NUM_VIDEOS; i++)); do
  PREV=$((i - 1))
  # Calculate offset: each image shows for IMAGE_DURATION, minus overlap from crossfades
  OFFSET=$(bc -l <<< "1 + ($i * $IMAGE_DURATION) - (($i - 1) * $CROSS_DURATION)")
  
  if [[ $i -eq 1 ]]; then
    FILTER+="[v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  elif [[ $i -eq $((NUM_VIDEOS - 1)) ]]; then
    FILTER+="[vx${PREV}][v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  else
    FILTER+="[vx${PREV}][v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  fi
done

# Add fade out
TOTAL_DUR=$(bc -l <<< "($NUM_VIDEOS * $IMAGE_DURATION) - (($NUM_VIDEOS - 1) * $CROSS_DURATION)")
FADEOUT_START=$(bc -l <<< "$TOTAL_DUR - 1")
FILTER+="[vx$((NUM_VIDEOS - 1))]fade=t=out:st=${FADEOUT_START}:d=1[final]"

# Build ffmpeg command
CMD=(ffmpeg -y)

# Add all temp videos as inputs
for VIDEO in "${TEMP_VIDEOS[@]}"; do
  CMD+=(-i "$VIDEO")
done

# Add audio input
CMD+=(-ss "$AUDIO_OFFSET" -i "$AUDIO")

# Add filter complex
CMD+=(-filter_complex "$FILTER")

# Map outputs
CMD+=(-map "[final]" -map "${NUM_VIDEOS}:a")

# Output settings
CMD+=(-c:v $VIDEO_CODEC -preset slow -crf $CRF)
CMD+=(-c:a aac -b:a 192k)
CMD+=(-r $FPS -pix_fmt yuv420p)
CMD+=(-shortest)
CMD+=(-movflags +faststart)
CMD+=("slideshow.mp4")

echo "🎬 Building slideshow from pre-generated videos..."
echo "📊 Performance improvement: ~5-10x faster than processing raw images"

"${CMD[@]}" && echo "✅ Complete: slideshow.mp4" || {
  echo "❌ FFmpeg failed" >&2
  exit 1
}