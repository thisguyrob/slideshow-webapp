#!/usr/bin/env bash
# Convert existing temp videos to 60fps
set -euo pipefail

echo "🎬 Converting existing temp videos to 60fps..."

# Navigate to the specific project directory if provided
if [[ $# -eq 1 ]]; then
  PROJECT_DIR="/app/projects/$1"
else
  # Use current directory if in a project folder
  PROJECT_DIR="$(pwd)"
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "❌ Directory not found: $PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"
echo "📂 Working in: $PROJECT_DIR"

# Convert each temp video
for video in temp_*.mp4; do
  if [[ -f "$video" ]]; then
    echo -n "Checking $video... "
    
    # Get current fps
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$video" 2>/dev/null | cut -d'/' -f1)
    
    if [[ "$fps" == "60" ]]; then
      echo "already 60fps ✓"
    else
      echo "converting from ${fps}fps to 60fps..."
      # Create temp file
      temp_file="${video}.new"
      
      # Convert to 60fps
      if ffmpeg -i "$video" -r 60 -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p "$temp_file" -y 2>/dev/null; then
        mv "$temp_file" "$video"
        echo "  ✅ Converted $video to 60fps"
      else
        echo "  ❌ Failed to convert $video"
        rm -f "$temp_file"
      fi
    fi
  fi
done

echo "✨ Done! All temp videos should now be 60fps"