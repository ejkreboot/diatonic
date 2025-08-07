#!/bin/bash

if [[ "$(uname)" != "Darwin" ]]; then
  echo "⚠️  This build / install script is for macOS only. Stay tuned for future developments!"
  exit 0
fi

# Parse command-line argument
if [[ "$1" == "--debug" ]]; then
  MODE="Debug"
  BUILD_FLAG="--debug"
  IS_DEBUG=true
else
  MODE="Release"
  BUILD_FLAG="--release"
  IS_DEBUG=false
fi

FFMPEG_SOURCE="./macos/Runner/Resources/ffmpeg"

if [[ ! -f "$FFMPEG_SOURCE" ]]; then
  echo "❌ Missing ffmpeg binary at $FFMPEG_SOURCE"
  echo "👉 Please run ./scripts/macos_configure.sh to build and install ffmpeg first."
  exit 1
fi

if [[ "$IS_DEBUG" == false ]]; then
  echo "🧼 Cleaning build..."
  flutter clean
fi

flutter pub get
flutter build macos $BUILD_FLAG

APP_BUNDLE="build/macos/Build/Products/${MODE}/diatonic.app"
APP_RESOURCES="${APP_BUNDLE}/Contents/Resources"

cp -f "$FFMPEG_SOURCE" "$APP_RESOURCES/"
chmod +x "$APP_RESOURCES/ffmpeg"

if [[ "$IS_DEBUG" == true ]]; then
  echo "🧪 Launching Diatonic.app in debug mode..."
  flutter run -d macos --use-application-binary "$APP_BUNDLE"
else
  rm -rf /Applications/Diatonic.app
  cp -R "$APP_BUNDLE" /Applications/Diatonic.app
  echo "✅ Diatonic.app (${MODE}) has been built and installed to /Applications."
fi
