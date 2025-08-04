#!/bin/bash

if [[ "$(uname)" != "Darwin" ]]; then
  echo "⚠️  This build / install script is for macOS only. Stay tuned for future developments!"
  exit 0
fi

flutter clean
flutter pub get
flutter build macos --release
rm -rf /Applications/Chorder.app
cp -R build/macos/Build/Products/Release/chorder.app /Applications/Chorder.app
