#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

APP_NAME="slower"
BUILD_DIR="./build/macos/Build/Products/Debug"
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
RESOURCES_PATH="$APP_PATH/Contents/Resources"
FFMPEG_SOURCE="./macos/Runner/Resources/ffmpeg"
FFMPEG_DEST="$RESOURCES_PATH/ffmpeg"

echo -e "${YELLOW}🔄 Ensuring Resources directory exists...${NC}"
mkdir -p "$RESOURCES_PATH"

if [ ! -f "$FFMPEG_SOURCE" ]; then
  echo -e "${RED}❌ Source ffmpeg binary not found at $FFMPEG_SOURCE${NC}"
  exit 1
fi

# Only copy if destination missing or source is newer
if [ ! -f "$FFMPEG_DEST" ] || [ "$FFMPEG_SOURCE" -nt "$FFMPEG_DEST" ]; then
  echo -e "${YELLOW}Copying ffmpeg into $RESOURCES_PATH...${NC}"
  cp "$FFMPEG_SOURCE" "$FFMPEG_DEST"
  chmod +x "$FFMPEG_DEST"
  echo -e "${GREEN}ffmpeg copied to Debug app bundle successfully!${NC}"
else
  echo -e "${GREEN}ffmpeg already up-to-date in Debug app bundle.${NC}"
fi
