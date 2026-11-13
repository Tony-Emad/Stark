#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$ROOT_DIR/dist/Stark.dmg"
PROFILE="${STARK_NOTARY_PROFILE:?Set STARK_NOTARY_PROFILE to an xcrun notarytool keychain profile name.}"

test -f "$DMG_PATH" || { echo "Build the DMG first: ./scripts/build_dmg.sh" >&2; exit 1; }
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature "$DMG_PATH"
echo "Notarized and stapled $DMG_PATH"
