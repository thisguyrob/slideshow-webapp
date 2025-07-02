#!/usr/bin/env bash
# ------------------------------------------------------------
# scavenger_hunt_slideshow_builder_v2.sh - Simplified & Reliable
# ------------------------------------------------------------
# Uses pre-rendered temp.mp4 videos with proper crossfade timing:
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

echo "🎬 Scavenger Hunt Slideshow Builder v2"
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

# Calculate total duration
TOTAL_DURATION=$((FADE_IN_DURATION + NUM_VIDEOS * HOLD_DURATION + (NUM_VIDEOS - 1) * CROSSFADE_DURATION + FADE_OUT_DURATION))
echo "⏱️  Total duration: ${TOTAL_DURATION}s"

# Create segments with proper timing
echo "🎞️ Preparing video segments..."

# Create black segment for fade in
ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=1:rate=${FPS}" \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
  "seg_black_start.mp4" 2>/dev/null

# Process each temp video to create properly timed segments
for ((i=0; i<NUM_VIDEOS; i++)); do
  VIDEO="${TEMP_VIDEOS[$i]}"
  
  if [[ $i -eq 0 ]]; then
    # First video: fade in + hold + half crossfade
    SEGMENT_DURATION=$(echo "$FADE_IN_DURATION + $HOLD_DURATION + 0.5" | bc)
  elif [[ $i -eq $((NUM_VIDEOS-1)) ]]; then
    # Last video: half crossfade + hold + fade out  
    SEGMENT_DURATION=$(echo "0.5 + $HOLD_DURATION + $FADE_OUT_DURATION" | bc)
  else
    # Middle videos: half crossfade + hold + half crossfade
    SEGMENT_DURATION=$(echo "0.5 + $HOLD_DURATION + 0.5" | bc)
  fi
  
  # Extend temp video to required duration
  ffmpeg -y -i "$VIDEO" -t "$SEGMENT_DURATION" -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
    "seg_video_${i}.mp4" 2>/dev/null
done

# Create black segment for fade out
ffmpeg -y -f lavfi -i "color=c=black:size=${TARGET_W}x${TARGET_H}:duration=1:rate=${FPS}" \
  -c:v "$VIDEO_CODEC" -preset fast -crf "$CRF" -pix_fmt yuv420p \
  "seg_black_end.mp4" 2>/dev/null

echo "🎬 Building slideshow with crossfades..."

# Build the complex xfade chain step by step
INPUTS=""
FILTER=""

# Add all inputs
INPUTS+="-i seg_black_start.mp4 "
for ((i=0; i<NUM_VIDEOS; i++)); do
  INPUTS+="-i seg_video_${i}.mp4 "
done
INPUTS+="-i seg_black_end.mp4 "
INPUTS+="-i $AUDIO_FILE "

# Build xfade chain
# Start: fade from black to first video
FILTER="[0:v][1:v]xfade=transition=fade:duration=${FADE_IN_DURATION}:offset=0[v1];"

# Chain crossfades between videos
for ((i=1; i<NUM_VIDEOS; i++)); do
  PREV_LABEL="v$i"
  NEXT_INPUT=$((i+1))
  NEXT_LABEL="v$((i+1))"
  
  # Calculate offset for each crossfade
  OFFSET=$(echo "$FADE_IN_DURATION + ($i - 1) * ($HOLD_DURATION + $CROSSFADE_DURATION) + $HOLD_DURATION" | bc)
  
  FILTER+="[${PREV_LABEL}][${NEXT_INPUT}:v]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${OFFSET}[${NEXT_LABEL}];"
done

# Final fade to black
LAST_LABEL="v${NUM_VIDEOS}"
BLACK_INPUT=$((NUM_VIDEOS + 1))
FINAL_OFFSET=$(echo "$FADE_IN_DURATION + ($NUM_VIDEOS - 1) * ($HOLD_DURATION + $CROSSFADE_DURATION) + $HOLD_DURATION" | bc)
FILTER+="[${LAST_LABEL}][${BLACK_INPUT}:v]xfade=transition=fade:duration=${FADE_OUT_DURATION}:offset=${FINAL_OFFSET}[vout]"

# Audio input index
AUDIO_INPUT=$((NUM_VIDEOS + 2))

echo "🚀 Rendering final slideshow..."

# Build and execute the final FFmpeg command
eval "ffmpeg -y $INPUTS \
  -filter_complex \"$FILTER\" \
  -map \"[vout]\" -map \"${AUDIO_INPUT}:a\" \
  -af \"afade=t=out:st=$FINAL_OFFSET:d=$FADE_OUT_DURATION\" \
  -c:v \"$VIDEO_CODEC\" -preset slow -crf \"$CRF\" \
  -c:a aac -b:a 192k -ar 44100 \
  -pix_fmt yuv420p -r \"$FPS\" \
  -t \"$TOTAL_DURATION\" \
  -movflags +faststart \
  slideshow.mp4" 2>/dev/null

# Cleanup temporary files
echo "🧹 Cleaning up..."
rm -f seg_*.mp4

if [[ -f "slideshow.mp4" ]]; then
  SIZE=$(du -h slideshow.mp4 | cut -f1)
  ACTUAL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 slideshow.mp4 2>/dev/null | cut -d. -f1)
  echo "✅ Slideshow created: slideshow.mp4 ($SIZE, ${ACTUAL_DURATION}s)"
  echo "📊 Timing: ${FADE_IN_DURATION}s fade in + ${NUM_VIDEOS}×${HOLD_DURATION}s holds + $((NUM_VIDEOS-1))×${CROSSFADE_DURATION}s crossfades + ${FADE_OUT_DURATION}s fade out"
else
  echo "❌ Failed to create slideshow" >&2
  exit 1
fi