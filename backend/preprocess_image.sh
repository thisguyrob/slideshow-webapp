#!/usr/bin/env bash
# ------------------------------------------------------------
# preprocess_image.sh - Pre-process single image to MP4
# ------------------------------------------------------------
# Creates a temp MP4 file with scaled/padded image
# These can be quickly concatenated during final render
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
FPS=60                # output frame rate (60fps for smooth transitions)
VIDEO_CODEC="libx264"
CRF=23                # Higher CRF for temp files (smaller size)
PAD_COLOR="black"     # padding color
DURATION=7            # Duration for crossfade overlap (5s display + 2s extra for transitions)

# --------------------------- Prerequisites ---------------------------
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ ffmpeg is not installed." >&2
  exit 1
fi

# --------------------------- Parameters ------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <input_image> <output_mp4>" >&2
  exit 1
fi

INPUT_IMAGE="$1"
OUTPUT_MP4="$2"

# Check if input exists
if [[ ! -f "$INPUT_IMAGE" ]]; then
  echo "❌ Input image not found: $INPUT_IMAGE" >&2
  exit 1
fi

# ------------------------- Geometry Filter --------------------------
GEOM="scale=w=${TARGET_W}:h=${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=${PAD_COLOR},setsar=1"

# Create MP4 with extra duration for transitions
ffmpeg -y -loop 1 -i "$INPUT_IMAGE" -t $DURATION \
  -vf "${GEOM},fps=${FPS}" \
  -c:v $VIDEO_CODEC -preset fast -crf $CRF \
  -pix_fmt yuv420p \
  "$OUTPUT_MP4" 2>/dev/null

if [[ $? -eq 0 ]]; then
  echo "✅ Pre-processed: $OUTPUT_MP4"
else
  echo "❌ Failed to pre-process image" >&2
  exit 1
fi