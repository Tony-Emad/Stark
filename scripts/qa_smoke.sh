#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift test
./scripts/verify_release.sh
./scripts/verify_dmg_contents.sh
echo "Stark automated QA smoke checks passed."
