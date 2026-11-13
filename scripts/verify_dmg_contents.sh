#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-$ROOT_DIR/dist/Stark.dmg}"
MOUNT_POINT="$(mktemp -d /tmp/stark-dmg-check.XXXXXX)"
DEVICE=""

cleanup() {
    if [[ -n "$DEVICE" ]]; then
        hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
    fi
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

test -f "$DMG_PATH" || { echo "DMG not found: $DMG_PATH" >&2; exit 1; }
DEVICE="$(hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_POINT" | awk 'NR==1 {print $1}')"
test -d "$MOUNT_POINT/Stark.app"
test -L "$MOUNT_POINT/Applications"
test -f "$MOUNT_POINT/Stark.app/Contents/Resources/Stark.icns"
codesign --verify --deep --strict "$MOUNT_POINT/Stark.app"
echo "DMG contents verified: $DMG_PATH"
