#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
APP_NAME="Diatonic"                          # display name (no .app)
APP_BUNDLE_NAME="${APP_NAME}.app"            # bundle name as it appears in Finder
IDENTITY="${IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-MyNotaryProfile}"

APP_PATH="./build/macos/Build/Products/Release/${APP_BUNDLE_NAME}"
DMG_NAME="${APP_NAME}-Installer.dmg"
DMG_BG="./macos/Packaging/DMG_bg.png"
FFMPEG_SOURCE="./macos/Runner/Resources/ffmpeg"
ENTITLEMENTS_PLIST="./macos/Runner/Release.entitlements"

# Flags
BUILD = true
BUILD_DMG=false
NOTARIZE=false
NO_CLEAN=false
WAIT_FOR_NOTARY=false
STAPLE_AFTER=false
NOTARIZE_EXISTING=false

usage() {
  cat <<EOF
Usage: $0 [options]
  --dmg                 Build a distributable DMG (implies signing; app still installed locally)
  --notarize            Submit DMG to Apple Notary Service (implies --dmg, async unless --wait)
  --notarize-existing   Notarize existing DMG ${DMG_NAME} (skips build & DMG creation)
  --wait                Wait for notarization result (implies --notarize)
  --staple              Staple ticket to DMG after successful notarization (implies --wait)
  --no-clean            Skip 'flutter clean' for faster iterative builds
  --no-build            Skip build (expect existing app bundle)
  --identity "Developer ID Application: Your Name (XX9X9X9XX9)"  Override signing identity (or set IDENTITY env)
  -h, --help            Show this help

Default behavior (no flags):
  Build release, sign app, replace /Applications/${APP_BUNDLE_NAME}.

Examples:
  export IDENTITY="Developer ID Application: Your Name (XX9X9X9XX9)"
  $0                         # build + install to /Applications
  $0 --dmg                   # build + install + create DMG
  $0 --notarize              # build + install + create DMG + submit for notarization
  $0 --dmg --no-clean        # faster rebuild DMG without cleaning
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg) BUILD_DMG=true; shift ;;
    --notarize) NOTARIZE=true; BUILD_DMG=true; shift ;;
    --notarize-existing) NOTARIZE=true; NOTARIZE_EXISTING=true; shift ;;
    --wait) WAIT_FOR_NOTARY=true; NOTARIZE=true; BUILD_DMG=true; shift ;;
    --staple) STAPLE_AFTER=true; WAIT_FOR_NOTARY=true; NOTARIZE=true; BUILD_DMG=true; shift ;;
    --no-clean) NO_CLEAN=true; shift ;;
    --no-build) BUILD=false; NO_CLEAN=true; shift ;;
  --identity) IDENTITY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if ! $NOTARIZE_EXISTING; then
  if [[ ! -f "$FFMPEG_SOURCE" ]]; then
    echo "❌ Missing ffmpeg binary at $FFMPEG_SOURCE"
    echo "👉 Please run ./scripts/macos_configure.sh to build and install ffmpeg first."
    exit 1
  fi
fi

# Reusable notarization routine
notarize_dmg() {
  local dmg_path="$1"
  if [[ ! -f "$dmg_path" ]]; then
    echo "❌ DMG not found: $dmg_path"; exit 1; fi
  echo "▶ Submitting DMG for notarization${WAIT_FOR_NOTARY:+ (will wait)}"
  xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --output-format normal)
  echo "ℹ️  Check status later: xcrun notarytool info SUBMISSION_ID --keychain-profile $NOTARY_PROFILE"
  echo "ℹ️  After acceptance: xcrun stapler staple \"$dmg_path\" && xcrun stapler validate \"$dmg_path\""
  fi
}

if $NOTARIZE_EXISTING; then
  echo "ℹ️  Notarizing existing DMG (skipping build & DMG creation)"
  notarize_dmg "$DMG_NAME"
  echo "🏁 Done."
  exit 0
fi

echo "▶ Building macOS app (Release)"
if ! $NO_CLEAN; then
  flutter clean
fi
flutter pub get
flutter build macos --release

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App not found at: $APP_PATH"
  exit 1
fi

# --- Codesign helpers ---
sign() {
  local target="$1"
  echo "🔏 Signing: $target"
  if [[ -n "$ENTITLEMENTS_PLIST" && -f "$ENTITLEMENTS_PLIST" ]]; then
    codesign --force --options runtime --timestamp \
      --entitlements "$ENTITLEMENTS_PLIST" \
      --sign "$IDENTITY" "$target"
  else
    codesign --force --options runtime --timestamp \
      --sign "$IDENTITY" "$target"
  fi
}

if [[ -z "$IDENTITY" ]]; then
  cat <<'EOF'
❌ No signing identity (IDENTITY) set.

Export one before running, e.g.:
  export IDENTITY="Developer ID Application: Eric Kort (UU9J7A9VZ2)"

List available identities:
  security find-identity -p codesigning -v

EOF
  exit 1
fi

echo "▶ Signing app bundle with IDENTITY: $IDENTITY"
sign "$APP_PATH"
echo "▶ Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" || { echo "❌ Deep verify failed"; exit 1; }
spctl -a -vv "$APP_PATH" || true

# --- Default install (copy to /Applications) ---
echo "📦 Installing to /Applications (default step)"
rm -rf "/Applications/${APP_BUNDLE_NAME}" || true
cp -R "$APP_PATH" "/Applications/${APP_BUNDLE_NAME}"
echo "✅ Installed /Applications/${APP_BUNDLE_NAME}"

if $BUILD_DMG; then
  echo "▶ Creating DMG"
  command -v create-dmg >/dev/null || { echo "Install with: brew install create-dmg"; exit 1; }
  rm -f "$DMG_NAME"
  create-dmg \
    --volname "${APP_NAME} Installer" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --background "$DMG_BG" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 64 \
    --icon "$APP_BUNDLE_NAME" 210 230 \
    --app-drop-link 390 230 \
    "$DMG_NAME" \
    "$APP_PATH"
  echo "✅ Created DMG: $DMG_NAME"

  if $NOTARIZE; then
    sign "$DMG_NAME"
    notarize_dmg "$DMG_NAME"
  fi
fi

echo "🏁 Done." 

