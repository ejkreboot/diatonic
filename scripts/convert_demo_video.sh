#!/usr/bin/env bash
set -euo pipefail

# convert_demo_video.sh
# Convert docs/assets/demo.mov to a lighter H.264/AAC MP4 for broad browser support.
# Usage:
#   ./scripts/convert_demo_video.sh [--in path/to/input.mov] [--out path/to/output.mp4]
# Options:
#   --crf <0-51>      Constant Rate Factor (lower = better/larger). Default: 22
#   --preset <name>   x264 speed/efficiency preset. Default: slow (use faster for speed)
#   --maxw <px>       Max width, maintain aspect ratio. Default: 1280
#   --fps <n>         Target frames per second. Default: 30
#
# The script looks for ffmpeg on PATH, falling back to ./macos/Runner/Resources/ffmpeg.

IN="docs/assets/demo.mov"
OUT="docs/assets/demo.mp4"
CRF=22
PRESET="slow"
MAXW=1280
FPS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --crf) CRF="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    --maxw) MAXW="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [--in path.mov] [--out path.mp4] [--crf N] [--preset NAME] [--maxw PX] [--fps N]
Examples:
  $0                    # convert docs/assets/demo.mov -> docs/assets/demo.mp4
  $0 --crf 24 --preset medium --maxw 1920 --fps 30
USAGE
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[[ -f "$IN" ]] || { echo "❌ Input not found: $IN"; exit 1; }
mkdir -p "$(dirname "$OUT")"

# Resolve ffmpeg
FFMPEG_BIN="ffmpeg"
if ! command -v ffmpeg >/dev/null 2>&1; then
  if [[ -x "./macos/Runner/Resources/ffmpeg" ]]; then
    FFMPEG_BIN="./macos/Runner/Resources/ffmpeg"
  else
    echo "❌ ffmpeg not found. Install via Homebrew: brew install ffmpeg" >&2
    exit 1
  fi
fi

echo "▶ Converting $IN -> $OUT"
"$FFMPEG_BIN" -y -hide_banner -loglevel info \
  -i "$IN" \
  -vf "scale='min($MAXW,iw)':-2:force_original_aspect_ratio=decrease" \
  -r "$FPS" \
  -c:v libx264 -profile:v high -level 4.1 -pix_fmt yuv420p -preset "$PRESET" -crf "$CRF" \
  -c:a aac -b:a 128k -ac 2 -ar 48000 \
  -movflags +faststart \
  "$OUT"

echo "✅ Wrote $OUT"
