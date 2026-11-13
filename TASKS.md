# Stark task board

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Done

- [x] Create an independent SwiftUI macOS project.
- [x] Build the setup experience as a notch-first top-center panel.
- [x] Add circular live preview, segmented scan ring, and head-position prompts.
- [x] Add Stark logo from the user-provided Downloads asset.
- [x] Add camera permission and live Vision face-presence detection.
- [x] Add Touch ID/password authorization with `LAContext`.
- [x] Add DMG build script.
- [x] Add proprietary LICENSE, NOTICE, and OWNERSHIP.md.
- [x] Add project README, plan, architecture, security, and release docs.

## P0 — next build

- [ ] Add guided face-enrollment screens.
- [ ] Choose and audit an on-device embedding model.
- [ ] Implement encrypted identity storage.
- [ ] Add explicit enrollment deletion and reset flows.
- [ ] Create unit tests for enrollment state and Keychain failure paths.

## P1 — security and reliability

- [ ] Implement identity matching with conservative thresholds.
- [ ] Implement liveness analysis as an independent gate.
- [ ] Add replay/photo/screen spoof test fixtures.
- [ ] Add camera selection and external-display behavior.
- [ ] Add session expiry and automatic re-authorization.
- [ ] Document threat model and recovery behavior.

## P2 — product polish

- [ ] Add notch/pill scan animation without copying reference artwork.
- [ ] Add onboarding, settings, and permission recovery screens.
- [ ] Add menu-bar controls and launch-at-login preference.
- [ ] Add proper Stark `.icns` asset.
- [ ] Add accessibility labels and keyboard navigation.

## P3 — distribution

- [ ] Add Developer ID signing configuration.
- [ ] Add notarization and stapling workflow.
- [ ] Test clean installation from DMG.
- [ ] Test uninstall and complete local-data deletion.
- [ ] Review all third-party licenses before release.
