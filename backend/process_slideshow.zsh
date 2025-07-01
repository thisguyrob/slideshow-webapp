#!/usr/bin/env zsh
# ---------------------------------------------------------------------------
# process_slideshow.zsh — Freedom Writers Foundation Slideshow Processor
# ---------------------------------------------------------------------------
# This script creates the final slideshow videos from Nico's prepared photos:
# 1. Processes each subfolder with photos and audio
# 2. Creates beat-synced slideshows (default) or crossfade slideshows (emotional)
# 3. Outputs individual slideshow.mp4 files in each subfolder
# 4. Concatenates all slideshows into final FWI-June-25-Slideshow.mp4
# ---------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=60
VIDEO_BITRATE="12M"
VIDEO_CODEC="libx264"
AUDIO_CODEC="aac"
AUDIO_BITRATE="192k"

# Crossfade settings for emotional tracks
IMAGE_DURATION=4      # seconds each image is fully visible
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

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    local deps=("ffmpeg" "ffprobe" "sips")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        if [[ " ${missing_deps[*]} " =~ " ffmpeg " ]]; then
            print_error "Install with: brew install ffmpeg"
        fi
        if [[ " ${missing_deps[*]} " =~ " sips " ]]; then
            print_error "sips should be available on macOS by default"
        fi
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Convert HEIF/HEIC images to JPG
convert_heif_images() {
    local folder="$1"
    print_status "Converting HEIF/HEIC images in $folder..."
    
    local converted=0
    
    # Check for HEIF/HEIC files with proper glob handling
    setopt NULL_GLOB
    local heif_files=("$folder"/*.{heic,HEIC,heif,HEIF})
    unsetopt NULL_GLOB
    
    for heif_file in "${heif_files[@]}"; do
        [[ -f "$heif_file" ]] || continue
        
        local base_name="${heif_file%.*}"
        local jpg_file="${base_name}.jpg"
        
        if [[ ! -f "$jpg_file" ]]; then
            print_status "Converting $(basename "$heif_file") to JPG..."
            if sips -s format jpeg "$heif_file" --out "$jpg_file" --setProperty formatOptions 90 >/dev/null 2>&1; then
                converted=$((converted + 1))
            else
                print_warning "Failed to convert $heif_file"
            fi
        fi
    done
    
    if [[ $converted -gt 0 ]]; then
        print_success "Converted $converted HEIF/HEIC images to JPG"
    fi
}

# Get sorted list of image files
get_image_files() {
    local folder="$1"
    local -a images=()
    
    # Find all supported image formats and sort them
    while IFS= read -r img; do
        [[ -f "$img" ]] && images+=("$img")
    done < <(find "$folder" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | sort -V)
    
    printf '%s\n' "${images[@]}"
}

# Create beat-synced slideshow
create_beat_synced_slideshow() {
    local folder="$1"
    print_status "Creating beat-synced slideshow for $folder..."
    
    # Read downbeats data
    local downbeats_file="$folder/downbeats.json"
    if [[ ! -f "$downbeats_file" ]]; then
        print_error "No downbeats.json found in $folder"
        return 1
    fi
    
    # Extract audio file and frame data using python
    local audio_file
    audio_file=$(python3 -c "
import json
with open('$downbeats_file', 'r') as f:
    data = json.load(f)
print(data['audio_file'])
" 2>/dev/null)
    
    if [[ ! -f "$audio_file" ]]; then
        # Try looking for song.mp3 in the folder instead
        audio_file="$folder/song.mp3"
        if [[ ! -f "$audio_file" ]]; then
            print_error "Audio file not found: $audio_file"
            return 1
        fi
    fi
    
    # Convert frames to times using python
    local -a times=()
    while IFS= read -r time_val; do
        [[ -n "$time_val" ]] && times+=("$time_val")
    done < <(python3 -c "
import json
with open('$downbeats_file', 'r') as f:
    data = json.load(f)
for frame in data['downbeat_frames']:
    print(frame / $VIDEO_FPS)
" 2>/dev/null)
    
    if [[ ${#times[@]} -eq 0 ]]; then
        print_error "No downbeat frames found in $downbeats_file"
        return 1
    fi
    
    print_status "Found ${#times[@]} downbeat times"
    print_status "First few times: ${times[1]} ${times[2]} ${times[3]} ..."
    
    # Get audio duration
    local audio_duration
    audio_duration=$(ffprobe -v error -show_entries format=duration -of csv="p=0" "$audio_file")
    times+=("$audio_duration")
    
    print_status "Total duration: $audio_duration seconds"
    
    # Get sorted images
    local -a images=()
    while IFS= read -r img; do
        [[ -n "$img" ]] && images+=("$img")
    done < <(get_image_files "$folder")
    
    print_status "Found ${#images[@]} images in $folder"
    if [[ ${#images[@]} -gt 0 ]]; then
        print_status "First few images: ${images[1]} ${images[2]} ${images[3]} ..."
    fi
    
    if [[ ${#images[@]} -lt $((${#times[@]} - 1)) ]]; then
        print_error "Need $((${#times[@]} - 1)) images but found ${#images[@]} in $folder"
        return 1
    fi
    
    # Create concat file for ffmpeg
    local concat_file
    concat_file=$(mktemp)
    
    print_status "Creating concat file with ${#times[@]} time points and ${#images[@]} images"
    
    # Note: zsh arrays are 1-indexed, loop through available images
    local num_segments=$((${#times[@]} - 1))  # minus 1 because last time is total duration
    
    for (( i=1; i<=num_segments && i<=${#images[@]}; i++ )); do
        local start_time="${times[$i]}"
        local end_time="${times[$((i+1))]}"
        local duration=$(python3 -c "print(max(0.033, $end_time - $start_time))")  # Min 2 frames
        
        print_status "Segment $i: ${images[$i]} for ${duration}s (${start_time}s to ${end_time}s)"
        
        printf "file '%s'\n" "$(realpath "${images[$i]}")" >> "$concat_file"
        printf "duration %s\n" "$duration" >> "$concat_file"
    done
    
    # Repeat last image for concat demuxer requirement
    if [[ ${#images[@]} -gt 0 ]]; then
        printf "file '%s'\n" "$(realpath "${images[${#images[@]}]}")" >> "$concat_file"
    fi
    
    # Create slideshow with proper scaling (fit images with black bars if needed)
    local output_file="$folder/slideshow.mp4"
    print_status "Rendering beat-synced slideshow..."
    
    if ! ffmpeg -y -hide_banner -loglevel warning \
        -f concat -safe 0 -i "$concat_file" \
        -i "$audio_file" \
        -map 0:v -map 1:a \
        -vf "scale=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2:black" \
        -c:v "$VIDEO_CODEC" -b:v "$VIDEO_BITRATE" -pix_fmt yuv420p \
        -c:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE" \
        -r "$VIDEO_FPS" -shortest \
        "$output_file"; then
        print_error "Failed to create slideshow for $folder"
        rm -f "$concat_file"
        return 1
    fi
    
    rm -f "$concat_file"
    print_success "Created beat-synced slideshow: $output_file"
    return 0
}

# Create crossfade slideshow for emotional tracks
create_crossfade_slideshow() {
    local folder="$1"
    print_status "Creating crossfade slideshow for $folder..."
    
    # Get audio file
    local audio_file="$folder/song.mp3"
    if [[ ! -f "$audio_file" ]]; then
        print_error "No song.mp3 found in $folder"
        return 1
    fi
    
    # Get sorted images
    local -a images=()
    while IFS= read -r img; do
        [[ -n "$img" ]] && images+=("$img")
    done < <(get_image_files "$folder")
    
    if [[ ${#images[@]} -eq 0 ]]; then
        print_error "No images found in $folder"
        return 1
    fi
    
    print_status "Found ${#images[@]} images for crossfade slideshow"
    
    # Build FFmpeg inputs
    local -a ffmpeg_inputs=()
    for img in "${images[@]}"; do
        ffmpeg_inputs+=(-loop 1 -t "$IMAGE_DURATION" -i "$img")
    done
    ffmpeg_inputs+=(-i "$audio_file")
    local audio_index=${#images[@]}
    
    # Build filter complex for crossfades
    local filter=""
    local total_images=${#images[@]}
    local overlap_start=$((IMAGE_DURATION - CROSSFADE_DURATION))
    
    # Scale and fade-in first image (zsh arrays are 1-indexed)
    filter+="[0:v]scale=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,fade=t=in:st=0:d=${FADE_DURATION}[v0];"
    
    # Chain crossfades for subsequent images
    for (( i=1; i<total_images; i++ )); do
        local prev=$((i - 1))
        local offset=$((overlap_start * i))
        filter+="[$i:v]scale=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:force_original_aspect_ratio=decrease,pad=${VIDEO_WIDTH}:${VIDEO_HEIGHT}:(ow-iw)/2:(oh-ih)/2:black[s$i];"
        filter+="[v$prev][s$i]xfade=transition=fade:duration=${CROSSFADE_DURATION}:offset=${offset}[v$i];"
    done
    
    # Fade out at the end
    local last_index=$((total_images - 1))
    local total_duration=$((IMAGE_DURATION * total_images - CROSSFADE_DURATION * (total_images - 1)))
    local fadeout_start=$((total_duration - FADE_DURATION))
    filter+="[v$last_index]fade=t=out:st=${fadeout_start}:d=${FADE_DURATION}[video]"
    
    # Audio fade out
    local audio_filter="afade=t=out:st=${fadeout_start}:d=${FADE_DURATION}"
    
    # Create slideshow
    local output_file="$folder/slideshow.mp4"
    print_status "Rendering crossfade slideshow (duration ≈ ${total_duration}s)..."
    
    if ! ffmpeg -y -hide_banner -loglevel warning \
        "${ffmpeg_inputs[@]}" \
        -filter_complex "$filter" \
        -map "[video]" -map "${audio_index}:a" \
        -af "$audio_filter" \
        -c:v "$VIDEO_CODEC" -b:v "$VIDEO_BITRATE" -pix_fmt yuv420p \
        -c:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE" \
        -r "$VIDEO_FPS" -shortest \
        "$output_file"; then
        print_error "Failed to create crossfade slideshow for $folder"
        return 1
    fi
    
    print_success "Created crossfade slideshow: $output_file"
    return 0
}

# Process a single subfolder
process_subfolder() {
    local folder="$1"
    print_status "Processing folder: $folder"
    
    # Check if folder has required files
    if [[ ! -f "$folder/song.mp3" ]]; then
        print_warning "No song.mp3 found in $folder - skipping"
        return 1
    fi
    
    # Convert HEIF/HEIC images
    convert_heif_images "$folder"
    
    # Check if this is an emotional track
    if [[ "$folder" == *"(emotional)"* ]]; then
        print_status "Detected emotional track - using crossfade approach"
        create_crossfade_slideshow "$folder"
    else
        print_status "Using beat-synced approach"
        if [[ ! -f "$folder/downbeats.json" ]]; then
            print_warning "No downbeats.json found in $folder - skipping"
            return 1
        fi
        create_beat_synced_slideshow "$folder"
    fi
}

# Concatenate all individual slideshows
create_final_slideshow() {
    print_status "Creating final combined slideshow..."
    
    # Find all individual slideshow files
    local -a slideshow_files=()
    for folder in */; do
        folder="${folder%/}"
        local slideshow_file="$folder/slideshow.mp4"
        if [[ -f "$slideshow_file" ]]; then
            slideshow_files+=("$slideshow_file")
        fi
    done
    
    if [[ ${#slideshow_files[@]} -eq 0 ]]; then
        print_warning "No individual slideshows found to combine"
        return 1
    fi
    
    print_status "Found ${#slideshow_files[@]} slideshows to combine"
    
    # Create concat file
    local concat_file
    concat_file=$(mktemp)
    
    for slideshow in "${slideshow_files[@]}"; do
        printf "file '%s'\n" "$(realpath "$slideshow")" >> "$concat_file"
    done
    
    # Concatenate all slideshows
    local final_output="FWI-June-25-Slideshow.mp4"
    print_status "Combining all slideshows into $final_output..."
    
    if ! ffmpeg -y -hide_banner -loglevel warning \
        -f concat -safe 0 -i "$concat_file" \
        -c:v "$VIDEO_CODEC" -b:v "$VIDEO_BITRATE" \
        -c:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE" \
        "$final_output"; then
        print_error "Failed to create final combined slideshow"
        rm -f "$concat_file"
        return 1
    fi
    
    rm -f "$concat_file"
    print_success "Created final slideshow: $final_output"
    return 0
}

# Main execution
main() {
    print_status "🎬 Freedom Writers Foundation Slideshow Processor"
    print_status "==============================================="
    
    # Check dependencies
    check_dependencies
    
    # Find all subfolders to process
    local -a subfolders=()
    for dir in */; do
        if [[ -d "$dir" && "$dir" != "slideshow_env/" ]]; then
            subfolders+=("${dir%/}")
        fi
    done
    
    if [[ ${#subfolders[@]} -eq 0 ]]; then
        print_warning "No subfolders found to process"
        exit 0
    fi
    
    print_status "Found ${#subfolders[@]} subfolder(s): ${subfolders[*]}"
    print_status ""
    
    # Process each subfolder
    local processed=0
    local failed=0
    
    for folder in "${subfolders[@]}"; do
        echo "==========================================="
        
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
    
    # Create final combined slideshow if we have any successful individual ones
    if [[ $processed -gt 0 ]]; then
        echo "==========================================="
        print_status "Creating final combined slideshow..."
        
        set +e
        create_final_slideshow
        local final_result=$?
        set -e
        
        if [[ $final_result -eq 0 ]]; then
            print_success "Final slideshow created successfully!"
        else
            print_error "Failed to create final combined slideshow"
        fi
    fi
    
    # Final summary
    echo "==========================================="
    print_success "Processing complete!"
    print_success "✓ Individual slideshows created: $processed"
    if [[ $failed -gt 0 ]]; then
        print_error "✗ Failed folders: $failed"
    fi
    
    if [[ $processed -gt 0 ]]; then
        print_status ""
        print_status "Output files created:"
        for folder in "${subfolders[@]}"; do
            if [[ -f "$folder/slideshow.mp4" ]]; then
                print_success "  • $folder/slideshow.mp4"
            fi
        done
        if [[ -f "FWI-June-25-Slideshow.mp4" ]]; then
            print_success "  • FWI-June-25-Slideshow.mp4 (final combined)"
        fi
    fi
    
    print_status ""
    print_status "🎉 All done! The slideshows are ready for the Freedom Writers!"
}

# Run main function
main "$@"