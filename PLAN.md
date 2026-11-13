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

Status: complete for the local MVP; production model audit remains a release gate.

- Capture guided enrollment poses. (done in prototype)
- Capture each pose automatically after a stable live-face confirmation. (done)
- Generate on-device Vision feature prints. (done in prototype)
- Store the identity record in the macOS Keychain. (done in prototype)
- Add identity deletion and reset controls. (done in prototype)
- Replace the prototype feature print with a face-specific audited embedding model.
- Add stronger consent, re-enrollment, and encrypted-at-rest review before release.

Atomic identity writes, identity serialization tests, and camera permission
recovery are implemented locally. The audited model and clean-account
Keychain-failure tests remain release gates.

## Phase 2 — matching and liveness

Status: complete for the local MVP; adversarial validation remains a release gate.

- Separate face detection, identity matching, and liveness gates. (done in prototype)
- Add rolling-window motion checks. (done in prototype)
- Keep the camera preview non-mirrored so movement instructions are unambiguous. (done)
- Test lighting, glasses, beard changes, printed photos, and screen replay. (manual QA matrix added)
- Keep manual password recovery available at all times.

The manual cases and evidence fields are listed in `docs/QA_FIXTURES.md`.

## Phase 3 — lock companion

Status: complete for the in-session MVP.

- Add a non-spoofing in-session lock companion surface. (done)
- Add manual lock, menu-bar controls, auto-lock, and Touch ID/password recovery. (done)
- Keep the completed setup panel dismissed after Done; reopen it only from the explicit setup command. (done)
- Observe supported sleep/wake transitions and re-lock Stark's own session. (done)
- Avoid impersonating Apple's system login window.

## Phase 4 — optional convenience bridge

Status: intentionally deferred.

The system-login password-entry bridge remains disabled because a camera scan
must not be represented as a direct macOS login authorization. Stark uses the
public Touch ID/password prompt for recovery instead.

## Phase 5 — release

Status: complete for local release automation; Developer ID credentials,
clean-install validation, and external hardware remain release gates.

- Add a production `.icns` icon. (done)
- Configure Developer ID signing and notarization scripts. (done; credentials remain external)
- Test Apple Silicon and Intel compatibility if both are supported. (cross-build and universal package verified)
- Publish privacy, security, recovery, uninstall, QA-fixture, and third-party documentation. (done locally)
