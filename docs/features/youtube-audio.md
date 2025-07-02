# YouTube Audio Processing

The application can download and process audio directly from YouTube. Users may
supply a URL and optional start time instead of uploading an audio file.

## Workflow

1. The backend uses `yt-dlp` to download the audio stream.
2. `ffmpeg` converts the result to MP3 format.
3. For scavenger hunt projects a 73‑second clip is trimmed from the chosen
   start time. Other project types run madmom beat detection for syncing.
4. Audio duration is validated to ensure the selected start time leaves enough
   material for processing. Helpful error messages guide the user if the video is
   too short.

These steps mirror the original shell script pipeline while adding length
validation and clearer feedback when processing YouTube sources.
