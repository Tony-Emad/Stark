# Stark — macOS Face-Scan Lock Experience

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.  
License: Proprietary — see `LICENSE` and `OWNERSHIP.md`.

## Project intent

Stark is a native macOS app for a calm, local, Face ID-like camera experience that can be paired with macOS authentication. The supplied face/scan illustration is the Stark app logo and is included at `Resources/StarkLogo.png`.

This repository currently contains a safe, compiling prototype. It detects face presence with Vision and authenticates the user with Apple's public LocalAuthentication flow (Touch ID when available, with the macOS password fallback). It does **not** yet claim to recognize an enrolled person or replace the macOS login window.

Stark uses local processing, clear scan states, an understated notch/pill visual language, multiple security gates, and an honest security warning. The implementation is proprietary and independent.

## Platform reality and security boundary

macOS has no public API that lets an ordinary third-party app directly approve the system lock/login window. A camera-based face scan on a MacBook is also not equivalent to Apple's hardware-backed Face ID: the built-in camera is a 2D sensor and is more exposed to spoofing.

Therefore Stark has two legitimate product modes:

1. **Recommended:** an in-session lock companion / screensaver-style experience that uses Vision for face presence and LocalAuthentication for an explicit Touch ID/password authorization.
2. **Optional, high-risk convenience mode:** after explicit opt-in, accessibility approval, local-only liveness and face-match checks, Stark may type a user-provided password into the visible login field. This must be off by default, never marketed as stronger than macOS security, and should be guarded by a short-lived Touch ID-protected key session. It must never run on a guessed or hidden window.

The current prototype intentionally implements only the first part of this boundary.

## MVP currently included

- Native SwiftUI macOS executable target, minimum macOS 15.
- Notch-first setup panel anchored at the top center with a black rounded panel.
- Circular live camera preview, segmented progress ring, head-position prompts, and compact setup steps.
- Camera permission flow and live camera preview.
- On-device `VNDetectFaceLandmarksRequest` face-presence detection.
- Visible states: ready, requesting camera, looking, face detected, authorized, unavailable.
- `LAContext` authorization using `deviceOwnerAuthentication`, which lets macOS use Touch ID and fall back to the account password.
- User-provided Stark logo in the app UI and DMG bundle.
- `scripts/build_dmg.sh` that produces `dist/Stark.dmg`.

## Next implementation phases

### Phase 1 — identity enrollment

- Add an enrollment flow with consent and clear deletion controls.
- Convert frames to embeddings using a vetted, on-device model; do not persist source camera images.
- Encrypt embeddings with a random AES key held in Keychain/Secure Enclave-backed access controls where supported.
- Add multiple identities and a disabled/enabled state per identity.

### Phase 2 — liveness and matching

- Separate face detection, identity matching, and liveness into independent gates.
- Require a rolling window of motion/landmark evidence; reject obvious printed/photo-screen cases.
- Add tests for false accepts, false rejects, lighting, glasses, beard changes, and camera framing.
- Keep a manual password path available at all times.

### Phase 3 — lock companion

- Add a full-screen, non-spoofing in-session lock companion or screensaver target.
- Detect sleep/wake and user lock/unlock transitions through supported public APIs.
- Avoid presenting a UI that impersonates Apple's login window.

### Phase 4 — optional Accessibility bridge

- Only if the product decision accepts the risk: implement a narrow, auditable bridge that acts only on a verified, visible password field after user opt-in.
- Keep the password in memory for the shortest possible time; never log it, sync it, or write it to ordinary files.
- Require a recent Touch ID/password authorization to unwrap the Keychain key.
- Add a panic/disable switch and a prominent recovery path.

### Phase 5 — distribution

- Add a real `.icns` asset derived from the Stark logo.
- Configure Developer ID signing, hardened runtime, camera privacy strings, and notarization.
- Test installation and removal on Apple Silicon and Intel if both are supported.

## Local build

Requirements: macOS 15+ and Xcode 27+.

```sh
swift build
./scripts/build_dmg.sh
open dist/Stark.dmg
```

The generated DMG is ad-hoc signed for local testing only. A public DMG must be Developer ID signed and notarized.

## Product wording

Use “face scan” or “face unlock companion” in Stark’s UI. Do not call the MacBook camera path “Face ID” unless Apple hardware or an equivalent depth-backed sensor is actually required and verified.
