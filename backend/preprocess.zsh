#!/usr/bin/env zsh
# ---------------------------------------------------------------------------
# preprocess.zsh — Freedom Writers Foundation Slideshow Preprocessor
# ---------------------------------------------------------------------------
# This script prepares everything Nico needs to create commemorative slideshows:
# 1. Sets up Python environment with all dependencies
# 2. Downloads audio from YouTube URLs in subfolders
# 3. For regular tracks: Detects downbeats using madmom
# 4. For "(emotional)" tracks: Calculates images needed based on crossfade timing
# 5. Creates temporary numbered images for each beat/crossfade position
# 
# Nico will then replace the numbered images with actual photos from the training.
# ---------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VENV_DIR="slideshow_env"
PYTHON_VERSION="3.9"
MADMOM_FPS=100
VIDEO_FPS=60
IMAGE_WIDTH=1920
IMAGE_HEIGHT=1080

# Emotional track settings (must match process_slideshow.zsh)
IMAGE_DURATION=5      # seconds each image is fully visible
CROSSFADE_DURATION=1  # seconds of crossfade between images
FADE_DURATION=1       # seconds for fade in/out

# Print colored output
print_status() {
    echo -e "${BLUE}ℹ︎${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install Homebrew dependencies
check_brew_dependencies() {
    print_status "Checking Homebrew dependencies..."
    
    if ! command_exists brew; then
        print_error "Homebrew is not installed. Please install it first:"
        print_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    local deps=("python@${PYTHON_VERSION}" "ffmpeg" "libsndfile" "imagemagick")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! brew list "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_status "Installing missing Homebrew packages: ${missing_deps[*]}"
        brew install "${missing_deps[@]}"
    fi
    
    # Install yt-dlp if not present
    if ! command_exists yt-dlp; then
        print_status "Installing yt-dlp..."
        brew install yt-dlp
    fi
    
    print_success "All Homebrew dependencies are installed"
}

# Setup Python virtual environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    local python_cmd="python${PYTHON_VERSION}"
    if ! command_exists "$python_cmd"; then
        python_cmd="python3"
    fi
    
    if [[ ! -d "$VENV_DIR" ]]; then
        print_status "Creating new virtual environment..."
        "$python_cmd" -m venv "$VENV_DIR"
    else
        print_status "Using existing virtual environment..."
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip first
    pip install --upgrade pip
    
    # Install Python dependencies
    print_status "Installing Python packages..."
    
    # Install specific numpy version first (madmom requirement)
    pip install "numpy==1.23.5"
    
    # Install cython (madmom requirement)
    pip install cython
    
    # Install madmom with specific flags
    pip install --no-use-pep517 madmom
    
    # Install Pillow for image creation
    pip install Pillow
    
    print_success "Python environment setup complete"
}

# Create temporary numbered image
create_numbered_image() {
    local number=$1
    local output_path=$2
    
    # Create image using Python/Pillow
    python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import sys

# Create a new image with white background
img = Image.new('RGB', (${IMAGE_WIDTH}, ${IMAGE_HEIGHT}), color='white')
draw = ImageDraw.Draw(img)

# Try to use a large font
try:
    # Try to find a good system font
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 200)
except:
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Arial.ttf', 200)
    except:
        # Fallback to default font
        font = ImageFont.load_default()

# Draw the number in the center
text = str(${number})
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (${IMAGE_WIDTH} - text_width) // 2
y = (${IMAGE_HEIGHT} - text_height) // 2

draw.text((x, y), text, fill='black', font=font)

# Save the image
img.save('${output_path}', 'JPEG', quality=95)
EOF
}

# Calculate number of images needed for emotional track
calculate_emotional_images() {
    local audio_file="$1"
    
    # Get audio duration using ffprobe
    local duration
    if ! duration=$(ffprobe -v error -show_entries format=duration -of csv="p=0" "$audio_file" 2>/dev/null); then
        print_error "Failed to get duration of $audio_file"
        return 1
    fi
    
    # Calculate number of images needed
    # Formula: num_images = ceil((duration - 2*fade_duration - crossfade_duration) / (image_duration - crossfade_duration))
    local num_images
    num_images=$(python3 -c "
import math
duration = $duration
image_duration = $IMAGE_DURATION
crossfade_duration = $CROSSFADE_DURATION
fade_duration = $FADE_DURATION

effective_duration = duration - 2 * fade_duration
if effective_duration <= 0:
    print(1)  # At least one image
else:
    num_images = math.ceil((effective_duration - crossfade_duration) / (image_duration - crossfade_duration))
    print(max(1, num_images))  # At least one image
")
    
    echo "$num_images"
}

# Process a single subfolder
process_subfolder() {
    local folder=$1
    print_status "Processing folder: $folder"
    
    # Check if this is an emotional track
    local is_emotional=false
    if [[ "$folder" == *"(emotional)"* ]]; then
        is_emotional=true
        print_status "Detected emotional track - will use crossfade timing instead of downbeats"
    fi
    
    # Read YouTube URL from audio.txt (we know it exists at this point)
    local youtube_url
    youtube_url=$(cat "$folder/audio.txt" | tr -d '\n\r ' | head -1)
    
    if [[ -z "$youtube_url" ]]; then
        print_error "Could not read YouTube URL from audio.txt in $folder"
        print_error "Please ensure audio.txt contains only the YouTube URL without extra lines or spaces"
        return 1
    fi
    
    # Validate YouTube URL format
    if [[ ! "$youtube_url" =~ ^https?://(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com) ]]; then
        print_error "Invalid YouTube URL in $folder/audio.txt: $youtube_url"
        print_error "Please ensure the URL starts with https://youtube.com, https://youtu.be, or https://music.youtube.com"
        return 1
    fi
    
    print_status "Found YouTube URL: $youtube_url"
    
    # Enter the subfolder
    if ! pushd "$folder" > /dev/null; then
        print_error "Could not enter directory $folder"
        return 1
    fi
    
    # Download audio if not already present
    if [[ ! -f "song.mp3" ]]; then
        print_status "Downloading audio..."
        if ! yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o "song.%(ext)s" "$youtube_url"; then
            print_error "Failed to download audio from $youtube_url"
            popd > /dev/null
            return 1
        fi
        print_success "Audio downloaded as song.mp3"
    else
        print_status "song.mp3 already exists - skipping download"
    fi
    
    # Process based on track type
    local num_images
    
    if [[ "$is_emotional" == true ]]; then
        # For emotional tracks, calculate images based on crossfade timing
        print_status "Calculating images needed for crossfade slideshow..."
        
        if ! num_images=$(calculate_emotional_images "song.mp3"); then
            print_error "Failed to calculate number of images needed"
            popd > /dev/null
            return 1
        fi
        
        print_success "Need $num_images images for crossfade slideshow"
        
        # Create a simple JSON file to indicate this is an emotional track
        cat > timing.json << EOF
{
  "audio_file": "$(realpath song.mp3)",
  "track_type": "emotional",
  "num_images": $num_images,
  "image_duration": $IMAGE_DURATION,
  "crossfade_duration": $CROSSFADE_DURATION,
  "fade_duration": $FADE_DURATION
}
EOF
        print_success "Created timing.json for emotional track"
        
    else
        # For regular tracks, process downbeats
        if [[ ! -f "downbeats.json" ]]; then
            print_status "Detecting downbeats in song.mp3..."
            
            # Create a temporary script to avoid issues with the main script's error handling
            cat > process_downbeats_temp.py << 'EOF'
import json
import os
import sys
from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor

try:
    # Set paths
    audio_path = "song.mp3"
    audio_abs_path = os.path.abspath(audio_path)
    
    # Extract downbeat activations  
    rnn_processor = RNNDownBeatProcessor()
    activations = rnn_processor(audio_path)
    
    # Downbeat tracking
    fps = 100
    tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=fps)
    downbeats = tracker(activations)
    
    # Convert to frame numbers (60fps video)
    video_fps = 60
    downbeat_frames = [round(time * video_fps) for time, beat_pos in downbeats if beat_pos == 1]
    
    # Save structured JSON output
    output_data = {
        "audio_file": audio_abs_path,
        "downbeat_frames": downbeat_frames
    }
    
    with open("downbeats.json", "w") as f:
        json.dump(output_data, f, indent=2)
    
    print(f"✅ Detected {len(downbeat_frames)} downbeats")
    
except Exception as e:
    print(f"❌ Error processing downbeats: {e}")
    sys.exit(1)
EOF
            
            if ! python3 process_downbeats_temp.py; then
                print_error "Failed to process downbeats for $folder"
                rm -f process_downbeats_temp.py
                popd > /dev/null
                return 1
            fi
            
            rm -f process_downbeats_temp.py
            print_success "Downbeats saved to downbeats.json"
        else
            print_status "downbeats.json already exists - skipping downbeat detection"
        fi
        
        # Read the number of downbeats
        if ! num_images=$(python3 -c "
import json
with open('downbeats.json', 'r') as f:
    data = json.load(f)
print(len(data['downbeat_frames']))
"); then
            print_error "Failed to read downbeats from JSON file"
            popd > /dev/null
            return 1
        fi
        
        print_success "Need $num_images images for beat-synced slideshow"
    fi
    
    print_status "Creating $num_images temporary numbered images..."
    
    # Create temporary numbered images
    for ((i=1; i<=num_images; i++)); do
        local img_name=$(printf "%03d.jpg" $i)
        if [[ ! -f "$img_name" ]]; then
            if ! create_numbered_image $i "$img_name"; then
                print_error "Failed to create image $img_name"
                popd > /dev/null
                return 1
            fi
        fi
    done
    
    print_success "Created temporary images: 001.jpg through $(printf "%03d.jpg" $num_images)"
    
    if [[ "$is_emotional" == true ]]; then
        print_success "Folder $folder is ready! (Emotional track - will use crossfades)"
    else
        print_success "Folder $folder is ready! (Regular track - will sync to downbeats)"
    fi
    
    popd > /dev/null
    return 0
}

# Main execution
main() {
    print_status "🎬 Freedom Writers Foundation Slideshow Preprocessor"
    print_status "================================================="
    
    # Check dependencies
    check_brew_dependencies
    
    # Setup Python environment
    setup_python_env
    
    # Find all subfolders (excluding the venv directory)
    local subfolders=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "$VENV_DIR/" ]]; then
            subfolders+=("${dir%/}")
        fi
    done
    
    if [[ ${#subfolders[@]} -eq 0 ]]; then
        print_warning "No subfolders found to process"
        exit 0
    fi
    
    print_status "Found ${#subfolders[@]} total subfolder(s): ${subfolders[*]}"
    
    # Pre-scan to find folders with audio.txt files
    local folders_to_process=()
    print_status "Scanning for folders with audio.txt files..."
    
    for folder in "${subfolders[@]}"; do
        if [[ -f "$folder/audio.txt" ]]; then
            folders_to_process+=("$folder")
            if [[ "$folder" == *"(emotional)"* ]]; then
                print_success "✓ $folder (has audio.txt - EMOTIONAL TRACK)"
            else
                print_success "✓ $folder (has audio.txt - REGULAR TRACK)"
            fi
        else
            print_warning "✗ $folder (no audio.txt)"
        fi
    done
    
    if [[ ${#folders_to_process[@]} -eq 0 ]]; then
        print_warning "No folders found with audio.txt files"
        exit 0
    fi
    
    print_status ""
    print_status "Will process ${#folders_to_process[@]} folder(s): ${folders_to_process[*]}"
    print_status ""
    
    # Process each folder that has audio.txt
    local processed=0
    local failed=0
    
    for folder in "${folders_to_process[@]}"; do
        echo "===========================================" 
        print_status "Processing folder: $folder"
        
        # Temporarily disable exit on error for this folder
        set +e
        process_subfolder "$folder"
        local result=$?
        set -e
        
        if [[ $result -eq 0 ]]; then
            processed=$((processed + 1))
        else
            print_error "Failed to process $folder"
            failed=$((failed + 1))
        fi
        echo # Add blank line between folders
    done
    
    # Final summary
    print_status "================================================="
    print_success "Preprocessing complete!"
    print_success "✓ Successfully processed: $processed folder(s)"
    if [[ $failed -gt 0 ]]; then
        print_error "✗ Failed to process: $failed folder(s)"
    fi
    
    print_status ""
    print_status "Next steps for Nico:"
    print_status "1. Go into each processed subfolder"  
    print_status "2. Replace the numbered images (001.jpg, 002.jpg, etc.) with actual photos"
    print_status "3. Keep the same filenames but use the real photos"
    print_status "4. Regular tracks will sync photos to musical downbeats"
    print_status "5. Emotional tracks will crossfade between photos smoothly"
    print_status "6. Run the main slideshow processing script when ready"
    
    # Deactivate virtual environment
    deactivate 2>/dev/null || true
}

# Run main function
main "$@"