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
- [x] Add guided face-enrollment screens.
- [x] Choose a local Vision feature-print implementation for the prototype.
- [x] Implement Keychain-backed identity storage.
- [x] Add explicit enrollment deletion and reset flows.
- [x] Implement identity matching with a conservative prototype threshold.
- [x] Implement liveness analysis as an independent motion gate.
- [x] Disable camera mirroring so the preview matches the user's natural view.
- [x] Automatically capture each enrollment pose after a live face is stable.
- [x] Resume incomplete enrollment at the next missing pose after reopening Stark.
- [x] Keep Done and close controls scoped to the notch panel; persist completed setup dismissal and restore setup only on explicit request.
- [x] Redesign Settings as readable cards instead of a cramped form.
- [x] Prevent launch-time Keychain authentication dialogs from appearing over the desktop.
- [x] Add in-session lock companion with manual recovery.
- [x] Add menu-bar controls, camera selection, launch-at-login, and auto-lock.
- [x] Re-lock Stark's own session around system sleep/wake notifications.
- [x] Add unit test target for the match policy.

## P0 — next build

- [ ] Replace the prototype feature print with a face-specific audited embedding model.
- [ ] Create unit tests for enrollment state and Keychain failure paths.

## P1 — security and reliability

- [ ] Add replay/photo/screen spoof test fixtures.
- [ ] Add camera selection and external-display behavior.
- [ ] Add session expiry and automatic re-authorization.
- [x] Add configurable auto-lock and Touch ID/password re-authorization.
- [ ] Document threat model and recovery behavior.

## P2 — product polish

- [ ] Add notch/pill scan animation without copying reference artwork.
- [ ] Add onboarding, settings, and permission recovery screens.
- [x] Add a readable card-based Settings window.
- [ ] Add menu-bar controls and launch-at-login preference.
- [x] Add proper Stark `.icns` asset.
- [x] Verify arm64 and x86_64 builds and package a universal app.
- [x] Add accessibility labels to critical unlock controls.

## P3 — distribution

- [ ] Add Developer ID signing configuration.
- [x] Add Developer ID signing and notarization scripts without embedded secrets.
- [x] Add repeatable universal release verification command and manual QA matrix.
- [ ] Test clean installation from DMG.
- [ ] Test uninstall and complete local-data deletion.
- [ ] Review all third-party licenses before release.
