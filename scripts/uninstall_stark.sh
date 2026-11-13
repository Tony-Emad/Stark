#!/bin/zsh
set -euo pipefail

if [[ "${1:-}" != "--purge" ]]; then
    echo "This removes Stark and its local identity. Run only when intended:"
    echo "  ./scripts/uninstall_stark.sh --purge"
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATHS=(
    "/Applications/Stark.app"
    "$ROOT_DIR/dist/Stark.app"
)

for app_path in "${APP_PATHS[@]}"; do
    if [[ -d "$app_path" ]]; then
        rm -rf -- "$app_path"
        echo "Removed $app_path"
    fi
done

security delete-generic-password -s "com.stark.app" -a "face-identity" >/dev/null 2>&1 || true
defaults delete "com.stark.app" >/dev/null 2>&1 || true
echo "Removed Stark's local Keychain identity and preferences."
