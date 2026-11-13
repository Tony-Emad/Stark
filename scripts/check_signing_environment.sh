#!/bin/zsh
set -euo pipefail

echo "Developer ID identities available on this Mac:"
security find-identity -v -p codesigning | grep "Developer ID Application" || {
    echo "No Developer ID Application identity found. Local ad-hoc builds still work."
}

if [[ -n "${STARK_SIGNING_IDENTITY:-}" ]]; then
    echo "STARK_SIGNING_IDENTITY is configured for this shell."
else
    echo "STARK_SIGNING_IDENTITY is not set; build_dmg.sh will use ad-hoc signing."
fi

if [[ -n "${STARK_NOTARY_PROFILE:-}" ]]; then
    echo "STARK_NOTARY_PROFILE is configured for this shell."
else
    echo "STARK_NOTARY_PROFILE is not set; notarization is not configured."
fi

echo "No signing secrets are stored in the repository."
