#!/usr/bin/env bash
# ------------------------------------------------------------
# process_single_emotional.sh - Emotional slideshow processor
# ------------------------------------------------------------
# This wrapper creates smooth crossfade slideshows for emotional
# tracks, designed to work with a single project directory
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=60
VIDEO_BITRATE="12M"
VIDEO_CODEC="libx264"
AUDIO_CODEC="aac"
AUDIO_BITRATE="192k"

# Crossfade settings
CROSSFADE_DURATION=3.0  # 3 seconds per crossfade
FADE_IN_DURATION=2.0
FADE_OUT_DURATION=3.0

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

echo "🎭 Processing emotional slideshow in current directory"

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

# Collect and sort images
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

echo "📸 Found ${#IMAGES[@]} images for emotional slideshow"

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

# Get audio duration
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO" | cut -d. -f1)
echo "🎵 Audio duration: ${AUDIO_DURATION}s (offset: $AUDIO_OFFSET)"

# Calculate timing
NUM_IMAGES=${#IMAGES[@]}
TOTAL_TRANSITIONS=$((NUM_IMAGES - 1))
TRANSITION_TIME=$(bc <<< "$TOTAL_TRANSITIONS * $CROSSFADE_DURATION")
STATIC_TIME=$(bc <<< "$AUDIO_DURATION - $TRANSITION_TIME - $FADE_IN_DURATION - $FADE_OUT_DURATION")

if (( $(bc <<< "$STATIC_TIME < 0") )); then
  echo "⚠️  Audio too short for smooth transitions. Adjusting crossfade duration..."
  CROSSFADE_DURATION=$(bc <<< "scale=2; ($AUDIO_DURATION - $FADE_IN_DURATION - $FADE_OUT_DURATION) / $TOTAL_TRANSITIONS * 0.8")
  STATIC_TIME=$(bc <<< "$AUDIO_DURATION - ($TOTAL_TRANSITIONS * $CROSSFADE_DURATION) - $FADE_IN_DURATION - $FADE_OUT_DURATION")
fi

IMAGE_DISPLAY_TIME=$(bc <<< "scale=2; $STATIC_TIME / $NUM_IMAGES + $CROSSFADE_DURATION")
echo "⏱️  Each image displays for ${IMAGE_DISPLAY_TIME}s (${CROSSFADE_DURATION}s crossfade)"

# Build filter complex
SCALE="scale=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black"

# Input setup
INPUTS=""
for IMG in "${IMAGES[@]}"; do
  INPUTS+=" -loop 1 -t $IMAGE_DISPLAY_TIME -i \"$IMG\""
done

# Create filter for smooth crossfades
FILTER=""
for ((i=0; i<NUM_IMAGES; i++)); do
  FILTER+="[$i:v]${SCALE},format=yuva420p[v$i];"
done

# Build crossfade chain
if [[ $NUM_IMAGES -eq 1 ]]; then
  # Single image - just fade in/out
  FILTER+="[v0]fade=t=in:d=${FADE_IN_DURATION},fade=t=out:st=$(bc <<< "$AUDIO_DURATION - $FADE_OUT_DURATION"):d=${FADE_OUT_DURATION}[outv]"
else
  # Multiple images - crossfade between them
  FILTER+="[v0][v1]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=$(bc <<< "$IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION")[vx1];"
  
  for ((i=2; i<NUM_IMAGES; i++)); do
    PREV=$((i-1))
    OFFSET=$(bc <<< "$PREV * ($IMAGE_DISPLAY_TIME - $CROSSFADE_DURATION)")
    if [[ $i -eq $((NUM_IMAGES-1)) ]]; then
      FILTER+="[vx${PREV}][v$i]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[vxfinal];"
    else
      FILTER+="[vx${PREV}][v$i]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[vx$i];"
    fi
  done
  
  # Add overall fade in/out
  if [[ $NUM_IMAGES -eq 2 ]]; then
    FILTER+="[vx1]fade=t=in:d=${FADE_IN_DURATION},fade=t=out:st=$(bc <<< "$AUDIO_DURATION - $FADE_OUT_DURATION"):d=${FADE_OUT_DURATION}[outv]"
  else
    FILTER+="[vxfinal]fade=t=in:d=${FADE_IN_DURATION},fade=t=out:st=$(bc <<< "$AUDIO_DURATION - $FADE_OUT_DURATION"):d=${FADE_OUT_DURATION}[outv]"
  fi
fi

# Build and run ffmpeg command
echo "🎬 Creating emotional slideshow..."
eval "ffmpeg -y $INPUTS -ss \"$AUDIO_OFFSET\" -i \"$AUDIO\" \
  -filter_complex \"$FILTER\" \
  -map '[outv]' -map $NUM_IMAGES:a \
  -c:v $VIDEO_CODEC -preset slow -b:v $VIDEO_BITRATE \
  -c:a $AUDIO_CODEC -b:a $AUDIO_BITRATE \
  -r $VIDEO_FPS -pix_fmt yuv420p \
  -t $AUDIO_DURATION \
  slideshow.mp4"

if [[ $? -eq 0 ]]; then
  echo "✅ Emotional slideshow complete: slideshow.mp4"
else
  echo "❌ FFmpeg failed" >&2
  exit 1
fi