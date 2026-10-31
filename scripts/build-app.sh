#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-0}"
PACKAGE_NAME="SubtitleConverter-macOS-arm64"
STAGING_DIR="$PWD/.build/$PACKAGE_NAME"
ZIP="$PWD/dist/$PACKAGE_NAME.zip"

if [[ "$NOTARIZE" == "1" && -z "$CODESIGN_IDENTITY" ]]; then
    echo "NOTARIZE=1 requires CODESIGN_IDENTITY." >&2
    exit 1
fi
if [[ "$NOTARIZE" == "1" && -z "$NOTARY_PROFILE" ]]; then
    echo "NOTARIZE=1 requires NOTARY_PROFILE." >&2
    exit 1
fi

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
if [[ -n "$CODESIGN_IDENTITY" ]]; then
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

mkdir -p "$STAGING_DIR"
ditto "$APP" "$STAGING_DIR/SubtitleConverter.app"
cp README.md "$STAGING_DIR/README.md"
ditto Examples/sample.srt "$STAGING_DIR/sample.srt"
cp "$PWD/dist/AppIcon-1024.png" "$STAGING_DIR/AppIcon-1024.png"
ditto "$ICONSET" "$STAGING_DIR/AppIcon.iconset"
cp "$PWD/dist/SubtitleConverter-v1.2-light.png" "$STAGING_DIR/SubtitleConverter-v1.2-light.png"
cp "$PWD/dist/SubtitleConverter-v1.2-dark.png" "$STAGING_DIR/SubtitleConverter-v1.2-dark.png"
ditto -c -k --keepParent "$STAGING_DIR" "$ZIP"

if [[ "$NOTARIZE" == "1" ]]; then
    echo "Submitting $ZIP for notarization..."
    if ! NOTARY_OUTPUT="$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"; then
        printf '%s\n' "$NOTARY_OUTPUT" >&2
        SUBMISSION_ID="$(printf '%s\n' "$NOTARY_OUTPUT" | awk '/^[[:space:]]*id: / { print $2; exit }')"
        if [[ -n "$SUBMISSION_ID" ]]; then
            xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
        fi
        exit 1
    fi
    printf '%s\n' "$NOTARY_OUTPUT"
    SUBMISSION_ID="$(printf '%s\n' "$NOTARY_OUTPUT" | awk '/^[[:space:]]*id: / { print $2; exit }')"
    NOTARY_STATUS="$(printf '%s\n' "$NOTARY_OUTPUT" | awk -F': ' '/^[[:space:]]*status: / { print $2; exit }')"
    if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
        echo "Apple notarization did not return Accepted (submission: ${SUBMISSION_ID:-unknown})." >&2
        if [[ -n "$SUBMISSION_ID" ]]; then
            xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
        fi
        exit 1
    fi
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl -a -vvv -t exec "$APP"
    ditto "$APP" "$STAGING_DIR/SubtitleConverter.app"
    ditto -c -k --keepParent "$STAGING_DIR" "$ZIP"
fi

printf '\n应用已生成：%s\n启动：open "%s"\n' "$APP" "$APP"
printf '发布压缩包：%s\n' "$ZIP"
