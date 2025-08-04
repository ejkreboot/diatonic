#!/bin/bash

set -e

echo "Running configure script for Slower macOS build..."

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
  ./scripts/macos_copy_ffmpeg.sh
else
  echo "✅ ffmpeg already present."
fi

# 4. Add ffmpeg to Xcode project via Ruby script
echo "Injecting ffmpeg into Xcode project (if needed)..."
ruby ./scripts/macos_add_ffmpeg_to_bundle.rb

# 5. Ensure MACOSX_DEPLOYMENT_TARGET = 11.0 in AppInfo.xcconfig
XCFILE="macos/Runner/Configs/AppInfo.xcconfig"
if grep -q "MACOSX_DEPLOYMENT_TARGET" "$XCFILE"; then
  echo "MACOSX_DEPLOYMENT_TARGET already set in AppInfo.xcconfig"
else
  echo "Setting MACOSX_DEPLOYMENT_TARGET = 11.0 in AppInfo.xcconfig"
  echo "MACOSX_DEPLOYMENT_TARGET = 11.0" >> "$XCFILE"
fi

echo "Configuration and build complete. Run 'flutter build macos' to build release version."
exit 0
