#!/usr/bin/env bash
echo "Testing ffmpeg in Docker..."
echo "Current directory: $(pwd)"
echo "FFmpeg location: $(which ffmpeg)"
echo "FFmpeg version:"
ffmpeg -version 2>&1 | head -3
echo ""
echo "Testing simple black video creation..."
ffmpeg -y -f lavfi -i "color=c=black:size=1920x1080:duration=1:rate=30" -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p test_black.mp4
if [[ -f test_black.mp4 ]]; then
  echo "✅ Test passed - ffmpeg can create videos"
  ls -la test_black.mp4
  rm -f test_black.mp4
else
  echo "❌ Test failed - ffmpeg cannot create videos"
fi