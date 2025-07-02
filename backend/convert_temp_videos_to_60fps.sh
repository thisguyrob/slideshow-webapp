#!/usr/bin/env bash
# Convert all temp videos in project directories to 60fps
set -euo pipefail

echo "🎬 Converting temp videos to 60fps..."

# Function to convert a single video
convert_video() {
  local input_file="$1"
  local temp_file="${input_file}.converting"
  
  echo "Converting: $input_file"
  
  # Convert to 60fps
  ffmpeg -i "$input_file" -r 60 -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p "$temp_file" -y 2>/dev/null
  
  if [[ $? -eq 0 ]]; then
    # Replace original with converted file
    mv "$temp_file" "$input_file"
    echo "✅ Converted: $input_file"
  else
    echo "❌ Failed to convert: $input_file"
    rm -f "$temp_file"
  fi
}

# Find all project directories
PROJECTS_DIR="/app/projects"
if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "Projects directory not found: $PROJECTS_DIR"
  exit 1
fi

# Convert all temp_*.mp4 files in all project directories
total=0
converted=0

for project_dir in "$PROJECTS_DIR"/*; do
  if [[ -d "$project_dir" ]]; then
    echo "Checking project: $(basename "$project_dir")"
    
    for video_file in "$project_dir"/temp_*.mp4; do
      if [[ -f "$video_file" ]]; then
        ((total++))
        
        # Check current frame rate
        current_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null | cut -d'/' -f1)
        
        if [[ "$current_fps" == "60" ]]; then
          echo "⏭️  Already 60fps: $video_file"
        else
          convert_video "$video_file"
          ((converted++))
        fi
      fi
    done
  fi
done

echo ""
echo "📊 Conversion complete!"
echo "Total temp videos found: $total"
echo "Videos converted to 60fps: $converted"