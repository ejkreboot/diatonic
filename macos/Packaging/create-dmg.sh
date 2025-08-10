#!/bin/bash
set -e

# Usage: ./create_dmg.sh /path/to/Diatonic.app

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Diatonic.app"
  exit 1
fi

# Check for create-dmg tool
command -v create-dmg >/dev/null 2>&1 || {
  echo "Error: create-dmg is not installed. Run: brew install create-dmg"
  exit 1
}

APP_PATH="$1"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: '$APP_PATH' is not a directory."
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
DMG_NAME="${APP_NAME%.app}-Installer.dmg"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Build DMG
create-dmg \
  --volname "${APP_NAME} Installer" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --background "$SCRIPT_DIR/DMG_bg.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 64 \
  --icon "$APP_NAME" 210 230 \
  --app-drop-link 390 230 \
  "$SCRIPT_DIR/$DMG_NAME" \
  "$APP_PATH"

echo "✅ Created DMG: $SCRIPT_DIR/$DMG_NAME"

# ------------------------------------------------------------
# Reminder: Add your notarization credentials to the keychain.
# Run this once (replace with your real Apple ID, Team ID, and App-Specific password):
#
# xcrun notarytool store-credentials "MyNotaryProfile" \
#   --apple-id "ericjkort@startmail.com" \
#   --team-id "UU9J7A9VZ2" \
#   --password "abcd-efgh-ijkl-mnop"
# ------------------------------------------------------------

echo "Submitting DMG for notarization..."
xcrun notarytool submit "$SCRIPT_DIR/$DMG_NAME" \
  --keychain-profile "MyNotaryProfile" \
  --wait  

xcrun stapler staple "$SCRIPT_DIR/$DMG_NAME"

echo "✅ Notarization complete."

mv "$SCRIPT_DIR/$DMG_NAME" "$SCRIPT_DIR/../landing_page/assets/"

echo "✅ Moved DMG to landing_page/assets/"
