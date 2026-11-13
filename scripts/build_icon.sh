#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/Resources/Stark.iconset"
SOURCE="$ROOT_DIR/Resources/StarkLogo.png"
OUTPUT="$ROOT_DIR/Resources/Stark.icns"

mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512 1024; do
    sips -z "$size" "$size" "$SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
echo "Created $OUTPUT"
