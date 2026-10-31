#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --configuration release
BIN_DIR="$(swift build --configuration release --show-bin-path)"
APP="$PWD/dist/SubtitleConverter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SubtitleConverter" "$APP/Contents/MacOS/SubtitleConverter"
cp Support/Info.plist "$APP/Contents/Info.plist"
MINIMUM_OS_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Support/Info.plist)"
SDK_VERSION="$(xcrun --show-sdk-version)"
vtool -set-build-version macos "$MINIMUM_OS_VERSION" "$SDK_VERSION" \
    -replace -output "$APP/Contents/MacOS/SubtitleConverter" "$APP/Contents/MacOS/SubtitleConverter"
ICONSET="$PWD/dist/AppIcon.iconset"
swift scripts/generate-app-icon.swift "$ICONSET" "$PWD/dist/AppIcon-1024.png"
iconutil --convert icns --output "$APP/Contents/Resources/AppIcon.icns" "$ICONSET"
vtool -show-build "$APP/Contents/MacOS/SubtitleConverter"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '\n应用已生成：%s\n启动：open "%s"\n' "$APP" "$APP"
