#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARM_BUILD_DIR="$ROOT_DIR/.build-arm64/out/Products/Release"
INTEL_BUILD_DIR="$ROOT_DIR/.build-x86_64/out/Products/Release"
APP_DIR="$ROOT_DIR/dist/Stark.app"
DMG_PATH="$ROOT_DIR/dist/Stark.dmg"

cd "$ROOT_DIR"
./scripts/build_icon.sh
swift build -c release --arch arm64 --scratch-path "$ROOT_DIR/.build-arm64"
swift build -c release --arch x86_64 --scratch-path "$ROOT_DIR/.build-x86_64"
rm -rf "$APP_DIR" "$DMG_PATH" "$ROOT_DIR/dist/Stark-dmg"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ROOT_DIR/dist/Stark-dmg"

lipo -create "$ARM_BUILD_DIR/Stark" "$INTEL_BUILD_DIR/Stark" -output "$APP_DIR/Contents/MacOS/Stark"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/StarkLogo.png" "$APP_DIR/Contents/Resources/StarkLogo.png"
cp "$ROOT_DIR/Resources/Stark.icns" "$APP_DIR/Contents/Resources/Stark.icns"
cp -R "$ARM_BUILD_DIR/Stark_Stark.bundle" "$APP_DIR/Contents/Resources/Stark_Stark.bundle"
ln -s /Applications "$ROOT_DIR/dist/Stark-dmg/Applications"
cp -R "$APP_DIR" "$ROOT_DIR/dist/Stark-dmg/Stark.app"

# Ad-hoc signing is the local default. Set STARK_SIGNING_IDENTITY to a
# Developer ID identity for a distributable build.
SIGNING_IDENTITY="${STARK_SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_DIR"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
fi
rm -rf "$ROOT_DIR/dist/Stark-dmg/Stark.app"
cp -R "$APP_DIR" "$ROOT_DIR/dist/Stark-dmg/Stark.app"
hdiutil create -volname "Stark" -srcfolder "$ROOT_DIR/dist/Stark-dmg" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Created $DMG_PATH"
