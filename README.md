# Stark

Stark is Tony Emad's native macOS face-scan lock companion prototype.

This project was built from scratch as an independent implementation. No
third-party source code or artwork is shipped by Stark.

## Current prototype

- SwiftUI macOS app targeting macOS 15+
- Notch-first setup panel anchored to the top center of the display
- Circular camera preview with segmented scan ring and head-position prompts
- On-device Vision face-presence detection
- Local Vision feature-print enrollment and conservative matching prototype
- Rolling motion-based liveness signal
- Keychain-backed local identity record with delete/reset control
- Touch ID/password authorization through Apple's public LocalAuthentication API
- User-provided Stark logo
- DMG packaging script

The prototype does not replace the macOS system login window and its camera
matching is not equivalent to hardware-backed biometric security. See
`STARK_PROJECT.md` for the security boundary and roadmap.

## Build

```sh
swift build
./scripts/build_dmg.sh
```

The generated DMG is for local testing. Public distribution requires Developer
ID signing and notarization.

## Ownership

Copyright © 2026 Tony Emad. All rights reserved. See `LICENSE`, `NOTICE`, and
`OWNERSHIP.md`.
