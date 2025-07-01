#!/bin/bash
# ------------------------------------------------------------
# test-docker.sh - Test the slideshow Docker container
# ------------------------------------------------------------
# This script tests all API endpoints to ensure the Docker
# container is working correctly
# ------------------------------------------------------------

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_BASE="http://localhost:3000/api"
TEST_PROJECT_NAME="Docker Test Project"
PROJECT_ID=""

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    echo -e "\n${YELLOW}Testing: $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

check_response() {
    local response=$1
    local expected=$2
    if [[ $response == *"$expected"* ]]; then
        return 0
    else
        return 1
    fi
}

# Start testing
echo "========================================="
echo "   Slideshow Docker Container Tests"
echo "========================================="

# 1. Check if server is running
log_test "Server health check"
if curl -s -f "${API_BASE%/api}/api/projects" > /dev/null; then
    log_success "Server is running"
else
    log_error "Server is not responding"
    exit 1
fi

# 2. Create a new project
log_test "Creating a new project"
CREATE_RESPONSE=$(curl -s -X POST "${API_BASE}/projects" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${TEST_PROJECT_NAME}\"}")

if check_response "$CREATE_RESPONSE" "id"; then
    PROJECT_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    log_success "Project created with ID: $PROJECT_ID"
else
    log_error "Failed to create project"
    echo "Response: $CREATE_RESPONSE"
    exit 1
fi

# 3. List projects
log_test "Listing projects"
LIST_RESPONSE=$(curl -s "${API_BASE}/projects")
if check_response "$LIST_RESPONSE" "$PROJECT_ID"; then
    log_success "Project appears in list"
else
    log_error "Project not found in list"
fi

# 4. Get project details
log_test "Getting project details"
DETAILS_RESPONSE=$(curl -s "${API_BASE}/projects/${PROJECT_ID}")
if check_response "$DETAILS_RESPONSE" "$TEST_PROJECT_NAME"; then
    log_success "Project details retrieved"
else
    log_error "Failed to get project details"
fi

# 5. Test YouTube URL endpoint
log_test "Setting YouTube URL"
YOUTUBE_RESPONSE=$(curl -s -X POST "${API_BASE}/upload/${PROJECT_ID}/youtube" \
    -H "Content-Type: application/json" \
    -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}')

if check_response "$YOUTUBE_RESPONSE" "YouTube URL saved successfully"; then
    log_success "YouTube URL saved"
else
    log_error "Failed to save YouTube URL"
fi

# 6. Create test image for upload
log_test "Creating test image"
TEST_IMAGE="/tmp/test-image.jpg"
# Create a small test image using ImageMagick if available, or a minimal JPEG
if command -v convert >/dev/null 2>&1; then
    convert -size 100x100 xc:blue "$TEST_IMAGE"
else
    # Create minimal JPEG header (this is a 1x1 white pixel JPEG)
    printf '\xff\xd8\xff\xe0\x00\x10\x4a\x46\x49\x46\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00\x43\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\x09\x09\x08\x0a\x0c\x14\x0d\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c\x20\x24\x2e\x27\x20\x22\x2c\x23\x1c\x1c\x28\x37\x29\x2c\x30\x31\x34\x34\x34\x1f\x27\x39\x3d\x38\x32\x3c\x2e\x33\x34\x32\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\xff\xc4\x00\xb5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01\x7d\x01\x02\x03\x00\x04\x11\x05\x12\x21\x31\x41\x06\x13\x51\x61\x07\x22\x71\x14\x32\x81\x91\xa1\x08\x23\x42\xb1\xc1\x15\x52\xd1\xf0\x24\x33\x62\x72\x82\x09\x0a\x16\x17\x18\x19\x1a\x25\x26\x27\x28\x29\x2a\x34\x35\x36\x37\x38\x39\x3a\x43\x44\x45\x46\x47\x48\x49\x4a\x53\x54\x55\x56\x57\x58\x59\x5a\x63\x64\x65\x66\x67\x68\x69\x6a\x73\x74\x75\x76\x77\x78\x79\x7a\x83\x84\x85\x86\x87\x88\x89\x8a\x92\x93\x94\x95\x96\x97\x98\x99\x9a\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00\xfb\xff\xd9' > "$TEST_IMAGE"
fi

if [[ -f "$TEST_IMAGE" ]]; then
    log_success "Test image created"
else
    log_error "Failed to create test image"
fi

# 7. Upload image
log_test "Uploading test image"
UPLOAD_RESPONSE=$(curl -s -X POST "${API_BASE}/upload/${PROJECT_ID}/images" \
    -F "images=@${TEST_IMAGE}")

if check_response "$UPLOAD_RESPONSE" "Images uploaded successfully"; then
    log_success "Image uploaded"
else
    log_error "Failed to upload image"
    echo "Response: $UPLOAD_RESPONSE"
fi

# 8. Create test audio file
log_test "Creating test audio"
TEST_AUDIO="/tmp/test-audio.mp3"
# Create a 5-second silent MP3 using ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 5 -q:a 9 "$TEST_AUDIO" -y >/dev/null 2>&1
    if [[ -f "$TEST_AUDIO" ]]; then
        log_success "Test audio created"
        
        # Upload audio
        log_test "Uploading test audio"
        AUDIO_UPLOAD_RESPONSE=$(curl -s -X POST "${API_BASE}/upload/${PROJECT_ID}/audio" \
            -F "audio=@${TEST_AUDIO}")
        
        if check_response "$AUDIO_UPLOAD_RESPONSE" "Audio uploaded successfully"; then
            log_success "Audio uploaded"
        else
            log_error "Failed to upload audio"
        fi
    else
        log_error "Failed to create test audio"
    fi
else
    log_error "ffmpeg not available for audio test"
fi

# 9. Test audio analysis
log_test "Analyzing audio"
ANALYZE_RESPONSE=$(curl -s -X POST "${API_BASE}/analyze/${PROJECT_ID}/analyze" \
    -H "Content-Type: application/json" \
    -d '{"audioType": "normal"}')

if check_response "$ANALYZE_RESPONSE" "requiredImages"; then
    log_success "Audio analyzed"
    echo "Analysis result: $ANALYZE_RESPONSE" | head -n 1
else
    log_error "Failed to analyze audio"
fi

# 10. Test process status
log_test "Checking process status"
STATUS_RESPONSE=$(curl -s "${API_BASE}/process/${PROJECT_ID}/status")
if check_response "$STATUS_RESPONSE" "isProcessing"; then
    log_success "Process status endpoint working"
else
    log_error "Process status endpoint failed"
fi

# 11. Update project metadata
log_test "Updating project metadata"
UPDATE_RESPONSE=$(curl -s -X PUT "${API_BASE}/projects/${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    -d '{"name": "Updated Test Project", "audioType": "emotional"}')

if check_response "$UPDATE_RESPONSE" "Updated Test Project"; then
    log_success "Project metadata updated"
else
    log_error "Failed to update project metadata"
fi

# 12. Test file deletion
log_test "Deleting uploaded file"
DELETE_FILE_RESPONSE=$(curl -s -X DELETE "${API_BASE}/upload/${PROJECT_ID}/files/test-image.jpg")
if check_response "$DELETE_FILE_RESPONSE" "deleted successfully"; then
    log_success "File deleted"
else
    log_error "Failed to delete file"
fi

# 13. Clean up - Delete test project
log_test "Cleaning up test project"
DELETE_RESPONSE=$(curl -s -X DELETE "${API_BASE}/projects/${PROJECT_ID}")
if check_response "$DELETE_RESPONSE" "deleted successfully"; then
    log_success "Test project deleted"
else
    log_error "Failed to delete test project"
fi

# Clean up temporary files
rm -f "$TEST_IMAGE" "$TEST_AUDIO"

# Summary
echo -e "\n========================================="
echo "           Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed! ✨${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi