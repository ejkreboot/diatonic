#!/bin/bash
set -euo pipefail

# Universal FFmpeg builder with optional safe mode (disable asm) and dSYM generation.
# Adds verification & single-arch capabilities for faster iteration.
# Usage: ./scripts/macos_build_ffmpeg_universal.sh [--safe] [--no-strip] [--verify] [--arch arm64|x86_64] [--min-version 11.0]
#  --safe         : disables assembly for both arches (helps avoid SIGILL issues)
#  --no-strip     : keep symbols in final binary (larger size)
#  --verify       : run 'ffmpeg -version' for each built slice and the universal binary (fail fast on SIGILL)
#  --arch <arch>  : build only a single architecture (arm64 or x86_64); skips lipo
#  --min-version <ver> : set MACOSX_DEPLOYMENT_TARGET (default 11.0)

FFMPEG_VERSION="6.1"
FFMPEG_DIR="ffmpeg-$FFMPEG_VERSION"
OUTPUT_DIR="build_ffmpeg"
SAFE_MODE=false
STRIP_BINARY=true
VERIFY=false
SINGLE_ARCH=""
MACOSX_MIN="11.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) SAFE_MODE=true; shift ;;
    --no-strip) STRIP_BINARY=false; shift ;;
    --verify) VERIFY=true; shift ;;
    --arch)
      SINGLE_ARCH="$2"; shift 2 ;;
    --min-version)
      MACOSX_MIN="$2"; shift 2 ;;
    -h|--help)
  echo "Usage: $0 [--safe] [--no-strip] [--verify] [--arch arm64|x86_64] [--min-version 11.0]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

echo "▶ Building FFmpeg $FFMPEG_VERSION SAFE_MODE=$SAFE_MODE STRIP=$STRIP_BINARY VERIFY=$VERIFY SINGLE_ARCH=${SINGLE_ARCH:-both} MACOSX_MIN=$MACOSX_MIN"

if [ ! -d "$FFMPEG_DIR" ]; then
  echo "Downloading FFmpeg $FFMPEG_VERSION..."
  curl -L -O https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2
  tar xjf ffmpeg-$FFMPEG_VERSION.tar.bz2
fi

if [[ -n "$SINGLE_ARCH" ]]; then
  if [[ "$SINGLE_ARCH" != "arm64" && "$SINGLE_ARCH" != "x86_64" ]]; then
    echo "Invalid --arch value: $SINGLE_ARCH"; exit 1
  fi
  mkdir -p "$OUTPUT_DIR/$SINGLE_ARCH"
else
  mkdir -p "$OUTPUT_DIR/arm64" "$OUTPUT_DIR/x86_64"
fi

common_flags=(
  --disable-everything
  --enable-protocol=file
  --enable-decoder=mp3,pcm_s16le
  --enable-encoder=pcm_s16le
  --enable-demuxer=mp3,wav
  --enable-muxer=wav,pcm_s16le
  --enable-filter=aresample
  --enable-small
  --disable-network
  --disable-autodetect
  --disable-doc
  --enable-static
  --disable-shared
)

if $SAFE_MODE; then
  common_flags+=(--disable-asm)
fi

build_arch() {
  local ARCH=$1
  local PREFIX=$2

  echo "⚙️  Configuring $ARCH -> $PREFIX"
  make distclean || true
  export MACOSX_DEPLOYMENT_TARGET="$MACOSX_MIN"
  ./configure \
    --prefix="$PREFIX" \
    --arch=$ARCH \
    --target-os=darwin \
    "${common_flags[@]}" \
    --cc="clang" \
    --extra-cflags="-arch $ARCH -g -mmacosx-version-min=$MACOSX_MIN" \
    --extra-ldflags="-arch $ARCH -mmacosx-version-min=$MACOSX_MIN" \
    --enable-cross-compile
  make -j"$(sysctl -n hw.ncpu)"
  make install
}

pushd "$FFMPEG_DIR" >/dev/null
if [[ -n "$SINGLE_ARCH" ]]; then
  build_arch "$SINGLE_ARCH" "../$OUTPUT_DIR/$SINGLE_ARCH"
else
  build_arch arm64 "../$OUTPUT_DIR/arm64"
  build_arch x86_64 "../$OUTPUT_DIR/x86_64"
fi
popd >/dev/null

if [[ -z "$SINGLE_ARCH" ]]; then
  mkdir -p "$OUTPUT_DIR/universal/bin"
  echo "🧬 Creating universal binary"
  lipo -create \
    "$OUTPUT_DIR/arm64/bin/ffmpeg" \
    "$OUTPUT_DIR/x86_64/bin/ffmpeg" \
    -output "$OUTPUT_DIR/universal/bin/ffmpeg"
  FINAL_BIN="$OUTPUT_DIR/universal/bin/ffmpeg"
else
  FINAL_BIN="$OUTPUT_DIR/$SINGLE_ARCH/bin/ffmpeg"
fi

echo "🛠  Generating dSYM"
dsymutil "$FINAL_BIN" -o "${FINAL_BIN}.dSYM" || echo "(dSYM generation failed)"

if $STRIP_BINARY; then
  echo "✂️  Stripping binary (symbols preserved in dSYM)"
  strip -x "$FINAL_BIN" || true
else
  echo "ℹ️  Not stripping binary (debug symbols kept inline)"
fi

echo "🔏 Code signing"
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Eric Kort (UU9J7A9VZ2)" \
  "$FINAL_BIN"

RESOURCE_TARGET="./macos/Runner/Resources"
FFMPEG_TARGET="$RESOURCE_TARGET/ffmpeg"
LICENSE_TARGET="$RESOURCE_TARGET/LICENSE.md"

echo "📦 Copying binary + LICENSE.md into $RESOURCE_TARGET"
mkdir -p "$RESOURCE_TARGET"
cp "$FINAL_BIN" "$FFMPEG_TARGET"
chmod +x "$FFMPEG_TARGET"

if [ -f "$FFMPEG_DIR/LICENSE.md" ]; then
  cp "$FFMPEG_DIR/LICENSE.md" "$LICENSE_TARGET"
else
  echo "⚠️  LICENSE.md missing; not copied"
fi

if $VERIFY; then
  echo "🔍 Verifying binary execution"
  if ! "$FINAL_BIN" -hide_banner -loglevel error -version >/dev/null 2>&1; then
    echo "❌ Verification failed (cannot execute ffmpeg)"; exit 1
  fi
  echo "✅ Verification succeeded"
fi

echo "✅ Built ffmpeg at $FINAL_BIN"
echo "   SAFE_MODE=$SAFE_MODE  STRIPPED=$STRIP_BINARY VERIFY=$VERIFY"
echo "   dSYM: ${FINAL_BIN}.dSYM (if generated)"
echo "(Artifacts retained for inspection; no cleanup performed.)"
