#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift test
./scripts/build_dmg.sh
codesign --verify --deep --strict dist/Stark.app
ARCHS="$(lipo -archs dist/Stark.app/Contents/MacOS/Stark)"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || {
    echo "Expected arm64 and x86_64 in the release binary; found: $ARCHS" >&2
    exit 1
}
test -f dist/Stark.app/Contents/Resources/Stark.icns
test -f dist/Stark.app/Contents/Resources/Stark_Stark.bundle/Contents/Resources/StarkLogo.png
echo "Stark release verification passed: $ARCHS"
