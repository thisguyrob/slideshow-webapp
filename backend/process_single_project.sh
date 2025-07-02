#!/usr/bin/env bash
# ------------------------------------------------------------
# process_single_project.sh - Process a single project folder
# ------------------------------------------------------------
# This wrapper script adapts the slideshow_builder.sh logic
# to work with a single project directory
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
IMAGE_DURATION=5      # seconds per image
CROSS_DURATION=1      # cross-fade duration
FPS=60                # output frame rate
VIDEO_CODEC="libx264"
CRF=18                # visually lossless ~18
PAD_COLOR="black"     # padding color: black, white, or #RRGGBB

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

# ------------------------- Geometry Filter --------------------------
GEOM="scale=w=${TARGET_W}:h=${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=${PAD_COLOR},setsar=1"

echo "▶︎ Processing slideshow in current directory"

# Check if audio.txt exists (YouTube URL)
if [[ -f "audio.txt" ]]; then
  URL=$(cat audio.txt)
  echo "📥 Downloading audio from YouTube..."
  yt-dlp -x --audio-format mp3 -o "audio.mp3" "$URL" || {
    echo "❌ Failed to download audio from YouTube" >&2
    exit 1
  }
fi

# Convert HEIC images if on Linux (using heif-convert)
if command -v heif-convert >/dev/null 2>&1; then
  for HEIC in *.heic *.HEIC *.heif *.HEIF; do
    [[ -f "$HEIC" ]] || continue
    JPG="${HEIC%.*}.jpg"
    echo "🔄 Converting $HEIC → $JPG"
    heif-convert "$HEIC" "$JPG" && rm "$HEIC"
  done
fi

# Collect image files
IMAGES=()
shopt -s nullglob nocaseglob
for IMG in *.jpg *.jpeg *.png; do
  IMAGES+=("$IMG")
done
shopt -u nullglob nocaseglob

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "⚠️  No images found"
  exit 1
fi

# Sort images alphanumerically
IFS=$'\n' IMAGES=($(sort -V <<<"${IMAGES[*]}"))
unset IFS

echo "📸 Found ${#IMAGES[@]} images"

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

# Build filter complex
FILTER="[0:v]${GEOM},fade=t=in:d=1:alpha=1[v0];"

# Add images with cross-fades
for ((i = 1; i < ${#IMAGES[@]}; i++)); do
  PREV=$((i - 1))
  FILTER+="[${i}:v]${GEOM},fade=t=in:d=1:alpha=1[v${i}];"
done

# Create cross-fade chain
FILTER+="[v0]"
for ((i = 1; i < ${#IMAGES[@]}; i++)); do
  PREV=$((i - 1))
  OFFSET=$(bc -l <<< "1 + ($i * $IMAGE_DURATION) - (($i - 1) * $CROSS_DURATION)")
  if [[ $i -eq 1 ]]; then
    FILTER+="[v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  elif [[ $i -eq $((${#IMAGES[@]} - 1)) ]]; then
    FILTER+="[vx${PREV}][v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  else
    FILTER+="[vx${PREV}][v${i}]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${OFFSET}[vx${i}];"
  fi
done

# Add fade out
TOTAL_DUR=$(bc -l <<< "(${#IMAGES[@]} * $IMAGE_DURATION) - ((${#IMAGES[@]} - 1) * $CROSS_DURATION)")
FADEOUT_START=$(bc -l <<< "$TOTAL_DUR - 1")
FILTER+="[vx$((${#IMAGES[@]} - 1))]fade=t=out:st=${FADEOUT_START}:d=1[final]"

# Build ffmpeg command
CMD=(ffmpeg -y)
for IMG in "${IMAGES[@]}"; do
  CMD+=(-loop 1 -t $IMAGE_DURATION -i "$IMG")
done
CMD+=(-ss "$AUDIO_OFFSET" -i "$AUDIO")
CMD+=(-filter_complex "$FILTER")
CMD+=(-map "[final]" -map "$((${#IMAGES[@]})):a")
CMD+=(-c:v $VIDEO_CODEC -preset slow -crf $CRF)
CMD+=(-c:a aac -b:a 192k)
CMD+=(-r $FPS -pix_fmt yuv420p)
CMD+=(-shortest)
CMD+=("slideshow.mp4")

echo "🎬 Building slideshow..."
"${CMD[@]}" && echo "✅ Complete: slideshow.mp4" || {
  echo "❌ FFmpeg failed" >&2
  exit 1
}