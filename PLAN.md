# Stark development plan

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Product goal

Build a native macOS face-scan lock companion with an elegant, local-first
experience, while keeping Stark's source, visual identity, and distribution
proprietary to Tony Emad.

## Phase 0 — foundation

Status: complete.

- Create an independent SwiftUI macOS app.
- Put the entire setup flow in a top-center notch panel.
- Add a circular camera preview, tick progress ring, and head-position prompts.
- Add the Stark logo and proprietary ownership files.
- Add camera permission and Vision face-presence detection.
- Add Touch ID/password authorization through LocalAuthentication.
- Produce a locally testable DMG.

## Phase 1 — real face enrollment

Status: next.

- Capture guided enrollment poses.
- Generate on-device face embeddings.
- Encrypt embeddings with a Keychain-protected key.
- Add identity deletion, re-enrollment, and consent screens.

## Phase 2 — matching and liveness

Status: planned.

- Separate face detection, identity matching, and liveness gates.
- Add rolling-window motion and landmark checks.
- Test lighting, glasses, beard changes, printed photos, and screen replay.
- Keep manual password recovery available at all times.

## Phase 3 — lock companion

Status: planned.

- Add a non-spoofing in-session lock companion or screensaver-style surface.
- Observe supported sleep/wake and lock/unlock transitions.
- Avoid impersonating Apple's system login window.

## Phase 4 — optional convenience bridge

Status: decision required.

- Evaluate whether a narrow Accessibility password-entry bridge is acceptable.
- Keep it off by default and require explicit consent.
- Require a recent Touch ID/password authorization before unwrapping any secret.
- Never log, sync, or persist the raw password in ordinary files.

## Phase 5 — release

Status: planned.

- Add a production `.icns` icon.
- Configure Developer ID signing and notarization.
- Test Apple Silicon and Intel compatibility if both are supported.
- Publish privacy, security, recovery, and uninstall documentation.
