#!/usr/bin/env bash
set -euo pipefail

# macos_publish.sh
# Modular macOS build / distribution utility for Diatonic.
# Subcommands:
#   build [--no-clean]      Build Release app bundle
#   codesign                Perform deep codesign of built bundle
#   diskimage               Create DMG from signed bundle
#   notarize                Submit DMG for notarization (async, prints Submission ID)
#   staple                  Staple notarization ticket to DMG and validate
#
# Environment overrides:
#   IDENTITY                 Developer ID Application identity
#   NOTARY_PROFILE           Keychain profile for notarytool
#   APP_NAME                 (default: Diatonic)
#   FFMPEG_SOURCE            Path to built ffmpeg binary to embed (optional check)
#
# Notes:
# - Commands are independent; run in order: build -> codesign -> diskimage -> notarize -> (after Accepted) staple.
# - No automatic waiting loop; check status manually:
#     xcrun notarytool info <submission_id> --keychain-profile "$NOTARY_PROFILE"
# - On an "Accepted" status you can staple.

APP_NAME="${APP_NAME:-Diatonic}"
APP_BUNDLE_NAME="${APP_NAME}.app"
IDENTITY="${IDENTITY:-Developer ID Application: Eric Kort (UU9J7A9VZ2)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-MyNotaryProfile}"
BUILD_DIR="./build/macos/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_BUNDLE_NAME}"
DMG_NAME="${APP_NAME}-Installer.dmg"
DMG_BG="./macos/Packaging/DMG_bg.png"
ENTITLEMENTS_PLIST="./macos/Runner/Release.entitlements"
FFMPEG_SOURCE="${FFMPEG_SOURCE:-./macos/Runner/Resources/ffmpeg}"   # expected location after prior script

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  build        [--no-clean]   Build Release bundle (flutter build macos)
  codesign                   Deep sign nested executables + bundle
  diskimage                  Create DMG from signed bundle (uses create-dmg)
  notarize                   Submit DMG for notarization (async only)
  staple                     Staple notarization ticket to DMG & validate

Examples:
  $0 build --no-clean
  $0 codesign
  $0 diskimage
  $0 notarize
  $0 staple

Manual notarization status check:
  xcrun notarytool info <submission_id> --keychain-profile $NOTARY_PROFILE

EOF
}

log() { printf '%s\n' "$*"; }
err() { printf '❌ %s\n' "$*" >&2; exit 1; }

require_tool() { command -v "$1" >/dev/null || err "Missing required tool: $1"; }

sign_one() {
  local target="$1"
  [[ ! -e "$target" ]] && return 0

  log "🔏 Sign: $target"

  # Decide if we should use entitlements (only for the main .app)
  local use_entitlements=false

  if [[ -n "$APP_PATH" ]]; then
    # Compare absolute paths to avoid symlink/relative issues
    local tgt_abs app_abs
    tgt_abs="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
    app_abs="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
    [[ "$tgt_abs" == "$app_abs" ]] && use_entitlements=true
  else
    # Fallback: any .app gets entitlements (e.g., if you don't have APP_BUNDLE set)
    [[ "$target" == *.app ]] && use_entitlements=true
  fi

  if $use_entitlements && [[ -n "$ENTITLEMENTS_PLIST" && -f "$ENTITLEMENTS_PLIST" ]]; then
    codesign --force --options runtime --timestamp \
      --entitlements "$ENTITLEMENTS_PLIST" \
      --sign "$IDENTITY" "$target"
  else
    codesign --force --options runtime --timestamp \
      --sign "$IDENTITY" "$target"
  fi
}

strip_xattrs() { command -v xattr >/dev/null || return 0; xattr -cr "$1" 2>/dev/null || true; }

deep_sign_internals() {
  local root="$1"
  log "🔍 Deep signing internals"

  # 1) Framework bundles (sign the bundle, not the symlinked Current)
  local fwdir="$root/Contents/Frameworks"
  if [[ -d "$fwdir" ]]; then
    while IFS= read -r -d '' fw; do
      # If you need a specific version: add --bundle-version=A
      sign_one "$fw"    # e.g., codesign -f --options runtime --timestamp -s "$ID" "$fw"
    done < <(find "$fwdir" -type d -name "*.framework" -prune -print0 2>/dev/null)
  fi

  # 2) Plug-ins (.bundle), app extensions, helpers
  local dirs=("$root/Contents/PlugIns" "$root/Contents/Library" "$root/Contents/XPCServices")
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r -d '' bundle; do
      sign_one "$bundle"
    done < <(find "$d" \( -name "*.bundle" -o -name "*.appex" -o -name "*.xpc" \) -print0 2>/dev/null)
  done

  # 3) Mach-O binaries outside bundles (executables, dylibs, tools)
  local more_dirs=("$root/Contents/MacOS" "$root/Contents/Frameworks" "$root/Contents/Resources")
  for d in "${more_dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r -d '' f; do
      if file "$f" | grep -q 'Mach-O'; then
        sign_one "$f"
      fi
    done < <(find "$d" -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.a" -o -perm -111 \) -print0 2>/dev/null)
  done
}


cmd_build() {
  local NO_CLEAN=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-clean) NO_CLEAN=true; shift ;;
      *) err "Unknown build option: $1" ;;
    esac
  done
  require_tool flutter
  if [[ ! -f "$FFMPEG_SOURCE" ]]; then
    log "⚠️  ffmpeg not found at $FFMPEG_SOURCE (continuing, ensure it's bundled separately)"
  fi
  log "▶ Building (Release)"
  if ! $NO_CLEAN; then flutter clean; fi
  flutter pub get
  flutter build macos --release
  [[ -d "$APP_PATH" ]] || err "App bundle not found at $APP_PATH"
  log "✅ Build complete: $APP_PATH"
}

cmd_codesign() {
  [[ -d "$APP_PATH" ]] || err "App bundle missing; run: $0 build"
  deep_sign_internals "$APP_PATH"
  sign_one "$APP_PATH"
  log "🔎 Verifying signature"
  if ! codesign --verify --deep --strict --verbose=2 "$APP_PATH"; then
    err "codesign verification failed"
  fi
  spctl -a -vv "$APP_PATH" || true
  log "✅ Codesign OK"
}

cmd_diskimage() {
  [[ -d "$APP_PATH" ]] || err "App bundle missing; run: $0 build"
  require_tool create-dmg
  [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]] || log "⚠️  Missing AppIcon.icns"
  local volname="${APP_NAME} Installer"
  rm -f "$DMG_NAME"
  log "▶ Creating DMG: $DMG_NAME"
  create-dmg \
    --volname "$volname" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    ${DMG_BG:+--background "$DMG_BG"} \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 64 \
    --icon "$APP_BUNDLE_NAME" 210 230 \
    --app-drop-link 390 230 \
    "$DMG_NAME" \
    "$APP_PATH" || err "create-dmg failed"
  [[ -f "$DMG_NAME" ]] || err "DMG not generated"
  log "✅ DMG created: $DMG_NAME"
}

cmd_notarize() {
  [[ -f "$DMG_NAME" ]] || err "DMG missing; run: $0 diskimage"
  require_tool xcrun
  
  log "🖊  Signing DMG: $DMG_NAME"
  # Sign DMG with Developer ID Application (no entitlements / no HR)
  if ! codesign --force --timestamp --sign "$IDENTITY" "$DMG_NAME"; then
    err "codesign (DMG) failed"
  fi
  log "✅ Codesign OK"
 
 log "▶ Submitting $DMG_NAME for notarization (async)"
  local json
  if ! json=$(xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --output-format json 2>/dev/null); then
    err "notarytool submit failed"
  fi
  local id
  id=$(echo "$json" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')
  [[ -n "$id" ]] || err "Could not parse submission ID"
  echo "$id" > .last_notary_submission
  log "🚀 Submission ID: $id"
  log "ℹ️  Check status: xcrun notarytool info $id --keychain-profile $NOTARY_PROFILE"
  log "ℹ️  After Accepted: $0 staple"
}

cmd_staple() {
  [[ -f "$DMG_NAME" ]] || err "DMG missing; run: $0 diskimage"
  require_tool xcrun
  log "▶ Stapling: $DMG_NAME"
  if ! xcrun stapler staple "$DMG_NAME"; then
    err "Staple failed (ensure notarization status is Accepted)"
  fi
  xcrun stapler validate "$DMG_NAME" || err "Staple validation failed"
  log "✅ Staple complete"
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    build)      cmd_build "$@" ;;
    codesign)   cmd_codesign "$@" ;;
    diskimage)  cmd_diskimage "$@" ;;
    notarize)   cmd_notarize "$@" ;;
    staple)     cmd_staple "$@" ;;
    ''|help|-h|--help) usage ;;
    *) err "Unknown command: $cmd" ;;
  esac
}

main "$@"
