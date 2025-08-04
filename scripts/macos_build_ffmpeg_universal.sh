#!/bin/bash

# build_ffmpeg_small_universal.sh
# Minimal universal FFmpeg builder (macOS Intel + ARM)
set -e

FFMPEG_VERSION="6.1"
FFMPEG_DIR="ffmpeg-$FFMPEG_VERSION"
OUTPUT_DIR="build_ffmpeg"

# 1. Download FFmpeg if needed
if [ ! -d "$FFMPEG_DIR" ]; then
  echo "Downloading FFmpeg $FFMPEG_VERSION..."
  curl -L -O https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2
  tar xjf ffmpeg-$FFMPEG_VERSION.tar.bz2
fi

mkdir -p "$OUTPUT_DIR/arm64" "$OUTPUT_DIR/x86_64"

# 2. Build for ARM64
cd "$FFMPEG_DIR"
make distclean || true # Clean any previous builds

echo "Configuring for ARM64..."
./configure \
  --prefix="../$OUTPUT_DIR/arm64" \
  --arch=arm64 \
  --target-os=darwin \
  --disable-everything \
  --disable-everything \
  --enable-protocol=file \
  --enable-decoder=mp3,pcm_s16le \
  --enable-encoder=pcm_s16le\
  --enable-demuxer=mp3,wav \
  --enable-muxer=wav,pcm_s16le \
  --enable-filter=aresample \
  --enable-small \
  --disable-network \
  --disable-autodetect \
  --disable-doc \
  --disable-debug \
  --enable-static \
  --disable-shared \
  --cc="clang" \
  --extra-cflags="-arch arm64" \
  --extra-ldflags="-arch arm64" \
  --enable-cross-compile

make -j$(sysctl -n hw.ncpu)
make install

make distclean

# 3. Build for x86_64
echo "Configuring for x86_64..."
./configure \
  --prefix="../$OUTPUT_DIR/x86_64" \
  --arch=x86_64 \
  --target-os=darwin \
  --disable-everything \
  --enable-protocol=file \
  --enable-decoder=mp3,pcm_s16le \
  --enable-encoder=pcm_s16le \
  --enable-demuxer=mp3,wav \
  --enable-muxer=wav,pcm_s16le \
  --enable-filter=aresample \
  --enable-small \
  --disable-network \
  --disable-autodetect \
  --disable-doc \
  --disable-debug \
  --enable-static \
  --disable-shared \
  --disable-x86asm \
  --cc="clang" \
  --extra-cflags="-arch x86_64" \
  --extra-ldflags="-arch x86_64"

make -j$(sysctl -n hw.ncpu)
make install

cd ..

# 4. Lipo them together
mkdir -p "$OUTPUT_DIR/universal/bin"
echo "Creating universal binary..."

lipo -create \
  "$OUTPUT_DIR/arm64/bin/ffmpeg" \
  "$OUTPUT_DIR/x86_64/bin/ffmpeg" \
  -output "$OUTPUT_DIR/universal/bin/ffmpeg"

echo "✅ Universal FFmpeg built successfully at $OUTPUT_DIR/universal/bin/ffmpeg"

# 5. Copy to Flutter macOS app Resources directory
RESOURCE_TARGET="./macos/Runner/Resources"
FFMPEG_TARGET="$RESOURCE_TARGET/ffmpeg"
LICENSE_TARGET="$RESOURCE_TARGET/LICENSE.md"

echo "Copying ffmpeg and LICENSE.md to $RESOURCE_TARGET..."
mkdir -p "$RESOURCE_TARGET"
cp "$OUTPUT_DIR/universal/bin/ffmpeg" "$FFMPEG_TARGET"
chmod +x "$FFMPEG_TARGET"

# 6. Also copy LICENSE.txt
if [ ! -f "$FFMPEG_DIR/LICENSE.md" ]; then
  echo "⚠️  LICENSE.md not found in ffmpeg source directory. Please provide it."
  exit 1
fi

cp "$FFMPEG_DIR/LICENSE.md" "$LICENSE_TARGET"

echo "✅ Copied ffmpeg and LICENSE.md to Flutter app Resources."

# 7. Clean up
echo "Cleaning up..."
rm -rf ffmpeg-$FFMPEG_VERSION*
rm -rf build_ffmpeg 
