#!/bin/bash

set -e

echo "Running configure script for Diatonic macOS build..."

# 1. Check platform
if [[ "$(uname)" != "Darwin" ]]; then
  echo "⚠️  This configure script is for macOS only. Stay tuned for future developments!"
  exit 0
fi

# 2. flutter clean
echo "Cleaning Flutter build..."
flutter clean

# 3. Check for FFmpeg binary
FFMPEG_PATH="./macos/Runner/Resources/ffmpeg"
if [[ ! -f "$FFMPEG_PATH" ]]; then
  echo "ffmpeg not found. Building..."
  ./scripts/macos_build_ffmpeg_universal.sh
else
  echo "✅ ffmpeg already present."
fi

# 4. Add ffmpeg to Xcode project via Ruby script
echo "Injecting ffmpeg into Xcode project (if needed)..."
ruby ./scripts/macos_add_ffmpeg_to_bundle.rb

echo "Configuration and build complete. Run './scripts/macos_build.sh' to build release version, or use --debug argument to build debug version."
exit 0
