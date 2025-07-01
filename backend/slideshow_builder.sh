#!/usr/bin/env bash
# ------------------------------------------------------------
# slideshow_builder.sh  —  macOS‑friendly slideshow generator
# ------------------------------------------------------------
# What it does in every subdirectory:
#   1. Checks prerequisites (`ffmpeg` + `yt‑dlp`).
#   2. Downloads the YouTube audio URL from `audio.txt` → `audio.mp3`.
#   3. Converts HEIC → JPG (macOS `sips`).
#   4. Collects all image files (*.jpg, *.jpeg, *.png) case‑insensitively,
#      sorts them alphanumerically.
#   5. Builds a 30 fps slideshow (`slideshow.mp4`):
#        • IMAGE_DURATION full seconds per image.
#        • CROSS_DURATION-second cross-fades between slides.
#        • 1‑second fade-in at start; 1‑second fade-out at end.
#        • Images scaled to FIT INSIDE TARGET_W×TARGET_H (letterbox/pillarbox).
#        • Audio starts at user-entered MM:SS offset per folder.
# ------------------------------------------------------------
set -euo pipefail

# ----------------------------- Settings -----------------------------
TARGET_W=1920         # canvas width
TARGET_H=1080         # canvas height
IMAGE_DURATION=5      # seconds per image
CROSS_DURATION=1      # cross-fade duration
FPS=30                # output frame rate
VIDEO_CODEC="libx264"
CRF=18                # visually lossless ~18
PAD_COLOR="black"     # padding color: black, white, or #RRGGBB

# --------------------------- Prerequisites ---------------------------
need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌  $1 is not installed. Install with: brew install $1" >&2
    exit 1
  }
}
need_tool ffmpeg
need_tool yt-dlp

# ------------------------- Geometry Filter --------------------------
# This ensures images FIT INSIDE the frame (letterbox/pillarbox as needed)
GEOM="scale=w=${TARGET_W}:h=${TARGET_H}:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=${PAD_COLOR},setsar=1"

# -------------------- Process Each Subdirectory --------------------
for DIR in */; do
  DIR="${DIR%/}"
  [[ ! -d "$DIR" ]] && continue
  echo "▶︎ Processing folder: $DIR"

  # Ask for MM:SS audio offset (default 00:00)
  read -r -p $'    ⏩  '$DIR' audio offset (MM:SS) [00:00]: ' AUDIO_OFFSET
  AUDIO_OFFSET=${AUDIO_OFFSET:-00:00}

  # Enter folder
  if ! pushd "$DIR" >/dev/null; then
    echo "  ❌  Could not enter $DIR – skipping."
    continue
  fi

  # 1️⃣ Download or copy audio
  if [[ -f audio.txt ]]; then
    if [[ ! -s audio.mp3 ]]; then
      echo "  • Downloading audio…"
      yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o "audio.%(ext)s" "$(< audio.txt)"
    else
      echo "  • audio.mp3 present – skipping download."
    fi
  else
    echo "  • No audio.txt here."
    if [[ -f ../audio.mp3 ]]; then
      echo "  • Using parent audio.mp3."
      cp ../audio.mp3 audio.mp3
    elif [[ -f ../audio.txt ]]; then
      echo "  • Downloading parent audio.txt…"
      cp ../audio.txt audio.txt
      yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o "audio.%(ext)s" "$(< audio.txt)"
    else
      echo "  • No audio source – skipping slideshow."
      popd >/dev/null
      continue
    fi
  fi

  # 2️⃣ Convert HEIC → JPG
  shopt -s nullglob nocaseglob
  for heic in *.heic; do
    jpg="${heic%.*}.jpg"
    if [[ ! -f "$jpg" ]]; then
      echo "  • Converting $heic → $jpg"
      sips -s format jpeg "$heic" --out "$jpg" --setProperty formatOptions 90 >/dev/null
    fi
  done
  shopt -u nocaseglob

  # 3️⃣ Gather & sort images
  shopt -s nullglob nocaseglob
  IMAGES=( *.jpg *.jpeg *.png )
  shopt -u nocaseglob
  if (( ${#IMAGES[@]} == 0 )); then
    echo "  • No images found – skipping slideshow."
    popd >/dev/null
    continue
  fi
  IFS=$'\n' IMAGES=( $(printf '%s\n' "${IMAGES[@]}" | sort -f) )
  echo "  • Found ${#IMAGES[@]} images (will fit inside ${TARGET_W}×${TARGET_H})"

  # 4️⃣ Build ffmpeg inputs (images + audio offset)
  INPUTS=()
  for IMG in "${IMAGES[@]}"; do
    INPUTS+=( -loop 1 -t "$IMAGE_DURATION" -i "$IMG" )
  done
  INPUTS+=( -ss "$AUDIO_OFFSET" -i audio.mp3 )
  AUDIO_INDEX=${#IMAGES[@]}

  # 5️⃣ Build filter_complex (crossfades & fades)
  FILTER=""
  TOTAL=${#IMAGES[@]}
  OVERLAP=$(( IMAGE_DURATION - CROSS_DURATION ))
  FILTER+="[0:v]${GEOM},fade=t=in:st=0:d=1[v0];"
  for ((i=1;i<TOTAL;i++)); do
    prev=$((i-1)) offset=$((OVERLAP*i))
    FILTER+="[$i:v]${GEOM}[s$i];"
    FILTER+="[v$prev][s$i]xfade=transition=fade:duration=${CROSS_DURATION}:offset=${offset},format=yuv420p[v$i];"
  done
  last="[v$((TOTAL-1))]"
  video_len=$((IMAGE_DURATION*TOTAL - CROSS_DURATION*(TOTAL-1)))
  FILTER+="$last fade=t=out:st=$((video_len-1)):d=1,format=yuv420p[video]"
  AFILT="afade=t=out:st=$((video_len-1)):d=1"

  echo "  • Rendering slideshow.mp4 (~${video_len}s, offset $AUDIO_OFFSET)"
  rm -f slideshow.mp4
  ffmpeg -hide_banner -y "${INPUTS[@]}" \
    -filter_complex "$FILTER" \
    -map "[video]" -map "${AUDIO_INDEX}:a" -af "$AFILT" \
    -r "$FPS" -c:v "$VIDEO_CODEC" -crf "$CRF" -pix_fmt yuv420p \
    -shortest slideshow_tmp.mp4
  mv slideshow_tmp.mp4 slideshow.mp4

  echo "  ✔ Done → $DIR/slideshow.mp4"
  popd >/dev/null

done