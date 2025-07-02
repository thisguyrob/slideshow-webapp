#!/usr/bin/env bash
# ------------------------------------------------------------
# scavenger_hunt_slideshow_builder_fixed.sh - Working Implementation
# ------------------------------------------------------------
# Uses the same proven crossfade logic as slideshow_builder.sh
# but adapted for pre-rendered temp.mp4 videos
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         
TARGET_H=1080         
IMAGE_DURATION=5      # seconds per slide (same as slideshow_builder.sh)
CROSS_DURATION=1      # cross-fade duration
FPS=60                
VIDEO_CODEC="libx264"
CRF=18                
MAX_IMAGES=12         

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ $1 is not installed." >&2
    exit 1
  }
}
need_tool ffmpeg
need_tool jq

echo "🎬 Fixed Scavenger Hunt Slideshow Builder (using proven method)"
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

# Use the EXACT same logic as slideshow_builder.sh
echo "🎬 Building slideshow using proven crossfade method..."

# Build ffmpeg inputs (exactly like slideshow_builder.sh)
INPUTS=()
for VIDEO in "${TEMP_VIDEOS[@]}"; do
  INPUTS+=( -loop 1 -t "$IMAGE_DURATION" -i "$VIDEO" )
done
INPUTS+=( -i "$AUDIO_FILE" )
AUDIO_INDEX=${#TEMP_VIDEOS[@]}

# Build filter_complex using the EXACT same pattern as slideshow_builder.sh
FILTER=""
TOTAL=${#TEMP_VIDEOS[@]}
OVERLAP=$(( IMAGE_DURATION - CROSS_DURATION ))

# First video with fade in (exactly like slideshow_builder.sh)
FILTER+="[0:v]fade=t=in:st=0:d=1[v0];"

# Crossfades between videos (exactly like slideshow_builder.sh)
for ((i=1;i<TOTAL;i++)); do
  prev=$((i-1)) 
  offset=$((1 + OVERLAP*i))
  FILTER+="[$i:v][s$i];"
  FILTER+="[v$prev][s$i]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${offset},format=yuv420p[v$i];"
done

# Final fade out (exactly like slideshow_builder.sh)
last="[v$((TOTAL-1))]"
video_len=$((IMAGE_DURATION*TOTAL - CROSS_DURATION*(TOTAL-1)))
FILTER+="$last fade=t=out:st=$((video_len-1)):d=1,format=yuv420p[video]"
AFILT="afade=t=out:st=$((video_len-1)):d=1"

echo "📊 Video length: ${video_len}s"
echo "🚀 Rendering slideshow..."

# Execute using the exact same command structure as slideshow_builder.sh
rm -f slideshow.mp4
ffmpeg -hide_banner -y "${INPUTS[@]}" \
  -filter_complex "$FILTER" \
  -map "[video]" -map "${AUDIO_INDEX}:a" -af "$AFILT" \
  -r "$FPS" -c:v "$VIDEO_CODEC" -crf "$CRF" -pix_fmt yuv420p \
  -shortest slideshow_tmp.mp4

mv slideshow_tmp.mp4 slideshow.mp4

if [[ -f "slideshow.mp4" ]]; then
  SIZE=$(du -h slideshow.mp4 | cut -f1)
  ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 slideshow.mp4 2>/dev/null | cut -d. -f1)
  echo "✅ Slideshow created: slideshow.mp4 ($SIZE, ${ACTUAL_DURATION}s)"
else
  echo "❌ Failed to create slideshow" >&2
  exit 1
fi