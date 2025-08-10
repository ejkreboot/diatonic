#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./notarize_build.sh build                # build, export, zip, submit (no wait)
#   ./notarize_build.sh status <SUBMISSION_ID>
#   ./notarize_build.sh history              # recent submissions (handy if you lost the ID)
#   ./notarize_build.sh staple <PATH_TO_APP_OR_DMG_OR_PKG>

# Requirements (run once):
#   xcrun notarytool store-credentials "MyNotaryProfile" --apple-id "<YOUR_APPLE_ID>" --team-id "<TEAM_ID>" --password "<APP_SPECIFIC_PW>"
#
NOTARY_PROFILE="${NOTARY_PROFILE:-MyNotaryProfile}"
TEAM_ID="${TEAM_ID:-UU9J7A9VZ2}"                    # <- your Team ID
SCHEME="${SCHEME:-Runner}"
CONFIG="${CONFIG:-Release}"
WORKSPACE="${WORKSPACE:-./macos/Runner.xcworkspace}"

ARCHIVE_PATH="${ARCHIVE_PATH:-./build/macos/${SCHEME}.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-./build/macos/export}"
ZIP_OUT="${ZIP_OUT:-./build/macos/AppForNotarization.zip}"

# Create a minimal ExportOptions.plist for Developer ID export
make_export_plist() {
  cat > "$1" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>teamID</key><string>TEAM_ID_PLACEHOLDER</string>
</dict></plist>
PLIST
  # inject team id
  /usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$1" >/dev/null
}

build_and_submit() {
  echo "📦 Archiving ($CONFIG)…"
  xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates

  echo "📤 Exporting .app for Developer ID…"
  rm -rf "$EXPORT_DIR"
  mkdir -p "$EXPORT_DIR"
  EXP_PLIST="$(mktemp)"
  make_export_plist "$EXP_PLIST"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXP_PLIST" \
    -exportPath "$EXPORT_DIR"

  rm -f "$EXP_PLIST"

  # Find the exported .app (usually at EXPORT_DIR/*.app)
  APP_PATH="$(/usr/bin/find "$EXPORT_DIR" -maxdepth 1 -name "*.app" -print -quit || true)"
  if [[ -z "${APP_PATH:-}" ]]; then
    echo "❌ Could not find exported .app in $EXPORT_DIR"
    exit 1
  fi
  echo "✅ Exported app: $APP_PATH"

  echo "🗜️  Zipping app for notarization…"
  rm -f "$ZIP_OUT"
  /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_OUT"
  echo "✅ ZIP ready: $ZIP_OUT"

  echo "🚀 Submitting to Apple Notary Service (no wait)…"
  SUBMIT_OUT="$(xcrun notarytool submit "$ZIP_OUT" --keychain-profile "$NOTARY_PROFILE" --output-format text)"
  SUBMISSION_ID="$(echo "$SUBMIT_OUT" | awk '/^ *id:/ {print $2; exit}')"

  if [[ -n "${SUBMISSION_ID:-}" ]]; then
    echo "✅ Submitted. Submission ID: $SUBMISSION_ID"
    echo "ℹ️ Check status with: $0 status $SUBMISSION_ID"
  else
    echo "⚠️ Could not parse submission ID. Use '$0 history' to locate it."
  fi

status_check() {
  local id="${1:-}"
  if [[ -z "$id" ]]; then
    echo "Usage: $0 status <SUBMISSION_ID>"
    exit 1
  fi
  xcrun notarytool info "$id" --keychain-profile "$NOTARY_PROFILE"
}

history_list() {
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE"
}

staple_it() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "Usage: $0 staple </path/to/.app|.dmg|.pkg>"
    exit 1
  fi
  echo "📎 Stapling: $target"
  xcrun stapler staple "$target"
  echo "✅ Stapled."
}

cmd="${1:-build}"
case "$cmd" in
  build)   build_and_submit ;;
  status)  shift; status_check "${1:-}" ;;
  history) history_list ;;
  staple)  shift; staple_it "${1:-}" ;;
  *) echo "Unknown command: $cmd"; exit 1 ;;
esac
