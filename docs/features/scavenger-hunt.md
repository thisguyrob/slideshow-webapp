# Scavenger Hunt Slideshow

This feature provides a fixed-timing slideshow designed for scavenger hunt events.
It enforces a strict 73‑second runtime with professional crossfades and optional
YouTube audio.

## Key Characteristics

- Exactly 12 images, each displayed for 5 seconds
- 1‑second fade in and fade out with 1‑second crossfades between slides
- Supports uploading audio or downloading from YouTube with start time trimming
- Optimized builder script generates the video in about 10–15 seconds

## Implementation Highlights

- `scavenger_hunt_slideshow_builder_v2.sh` pre-renders short video segments and
  stitches them together with FFmpeg crossfades for smooth transitions.
- Timing fixes ensure the first and last images display for the correct
duration and that the audio fades out with the final slide.
- Backend endpoints detect the project type and trim or validate audio length to
  exactly 73 seconds.

These improvements dramatically reduce processing time while ensuring consistent
results across all scavenger hunt projects.
