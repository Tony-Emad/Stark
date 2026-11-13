# Stark architecture

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Current modules

`StarkModel` owns the prototype state, camera lifecycle, Vision face-presence
request, setup steps, identity store, and LocalAuthentication prompt. `StarkNotchView` renders
the entire setup experience as a top-center panel with a circular preview,
segmented ring, and head-position prompt. `StarkWindowController` turns the
SwiftUI window into a borderless status-level panel and anchors it to the top
center of the display. `CameraPreview` bridges `AVCaptureVideoPreviewLayer`
into SwiftUI. `scripts/build_dmg.sh` creates the local-test application bundle
and DMG.

## Target modules

```text
StarkApp
├── AppShell / menu bar / onboarding
├── CameraService
├── FaceDetector
├── FaceRecognitionService (Vision feature print + liveness prototype)
├── FaceMatcher
├── IdentityStore / KeychainStore
├── CredentialVault
├── LocalAuthCoordinator
├── LockCompanion
└── Distribution / signing / updater
```

Recognition and liveness must remain separate from credential authorization.
No face match is allowed to become an unlock decision without a valid session,
identity match, liveness result, visible target state, and the configured
fallback path.

## Data flow

```text
Camera frame → Vision detection → face crop → feature print
                                      ├→ identity match
                                      └→ liveness gate

identity + liveness + authorized session → user-visible unlock action
```

Camera frames should be processed in memory and discarded. Only the minimum
derived data needed for the local product should be retained.
