#!/usr/bin/env bash
# ------------------------------------------------------------
# scavenger_hunt_slideshow_builder.sh - Fixed Implementation  
# ------------------------------------------------------------
# Uses the proven crossfade logic from slideshow_builder.sh
# correctly adapted for pre-rendered temp.mp4 videos
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         
TARGET_H=1080         
IMAGE_DURATION=5      # seconds per slide
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

echo "🎬 Fixed Scavenger Hunt Slideshow Builder"
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

# Build ffmpeg inputs (will extend duration in filter)
INPUTS=()
for VIDEO in "${TEMP_VIDEOS[@]}"; do
  INPUTS+=( -i "$VIDEO" )
done
INPUTS+=( -i "$AUDIO_FILE" )
AUDIO_INDEX=${#TEMP_VIDEOS[@]}

# First, extend each temp video to required duration using filter
echo "🎬 Extending temp videos and building slideshow..."

# Build filter for correct timing: 5s holds + 1s crossfades
FILTER=""
TOTAL=${#TEMP_VIDEOS[@]}
SEGMENT_DURATION=$((IMAGE_DURATION + CROSS_DURATION))  # 6 seconds per segment

# Extend each video to 6 seconds (5s hold + 1s crossfade time)
# First video: fade in + hold + crossfade time
FILTER+="[0:v]tpad=stop_mode=clone:stop_duration=$((SEGMENT_DURATION-1)),fade=t=in:st=0:d=1[v0];"

# Process each subsequent video with extension and crossfade  
for ((i=1;i<TOTAL;i++)); do
  prev=$((i-1)) 
  # Offset: 1s fade in + 5s hold + (i-1) * 6s segments = 6 + (i-1) * 6
  offset=$((6 + (i-1) * SEGMENT_DURATION))
  
  # Extend video to 6 seconds and label it
  FILTER+="[$i:v]tpad=stop_mode=clone:stop_duration=$((SEGMENT_DURATION-1))[s$i];"
  # Crossfade previous result with extended input
  FILTER+="[v$prev][s$i]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${offset},format=yuv420p[v$i];"
done

# Final fade out: total time is 1 + 12*5 + 11*1 + 1 = 73 seconds
# Fade out starts at 72s for 1s
last="[v$((TOTAL-1))]"
video_len=73
fade_out_start=72
FILTER+="$last fade=t=out:st=${fade_out_start}:d=1,format=yuv420p[video]"
AFILT="afade=t=out:st=${fade_out_start}:d=1"

echo "📊 Video length: ${video_len}s"
echo "⏱️  Timing: 1s fade in + ${TOTAL}×${IMAGE_DURATION}s holds + $((TOTAL-1))×${CROSS_DURATION}s crossfades + 1s fade out"
echo "🔢 Crossfade offsets: $(for ((i=1;i<TOTAL;i++)); do echo -n "$((6 + (i-1) * SEGMENT_DURATION))s "; done)"
echo "⬇️  Fade out starts at: ${fade_out_start}s"
echo "🚀 Rendering slideshow..."

# Execute using exact same command structure as slideshow_builder.sh
rm -f slideshow.mp4
ffmpeg -hide_banner -y "${INPUTS[@]}" \
  -filter_complex "$FILTER" \
  -map "[video]" -map "${AUDIO_INDEX}:a" -af "$AFILT" \
  -r "$FPS" -c:v "$VIDEO_CODEC" -crf "$CRF" -pix_fmt yuv420p \
  -t "$video_len" \
  slideshow_tmp.mp4

mv slideshow_tmp.mp4 slideshow.mp4

if [[ -f "slideshow.mp4" ]]; then
  SIZE=$(du -h slideshow.mp4 | cut -f1)
  ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 slideshow.mp4 2>/dev/null | cut -d. -f1)
  echo "✅ Slideshow created: slideshow.mp4 ($SIZE, ${ACTUAL_DURATION}s)"
else
  echo "❌ Failed to create slideshow" >&2
  exit 1
fi