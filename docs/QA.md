# Stark QA matrix

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Automated checks

- [x] `swift test`
- [x] Release build completes.
- [x] DMG is generated.
- [x] App bundle passes ad-hoc code-sign verification.
- [x] App binary contains arm64 and x86_64.
- [x] App bundle contains the Stark icon and resource bundle.

Run all automated checks with:

```sh
./scripts/verify_release.sh
```

## Manual Mac checks

- [ ] Launch the app on an Apple Silicon Mac and confirm the panel is anchored to the top center.
- [ ] Launch the app on an Intel Mac and confirm the panel and camera preview work.
- [ ] Deny camera permission and confirm Stark explains how to recover it.
- [ ] Allow camera permission and confirm face presence updates the scan state.
- [ ] Capture all guided poses and confirm samples persist after relaunch.
- [ ] Confirm a saved setup can be deleted from Settings.
- [ ] Confirm Touch ID/password authorization succeeds and cancellation is recoverable.
- [ ] Confirm manual Lock Stark and auto-lock both require fresh authorization.
- [ ] Confirm sleep/wake re-locks Stark's own session.
- [ ] Select an external camera and confirm the live preview switches.
- [ ] Enable launch-at-login and confirm the setting can be disabled again.
- [ ] Install the DMG on a clean Mac and confirm the app opens.

## Adversarial validation before public release

- [ ] Test printed photos.
- [ ] Test a phone-screen replay.
- [ ] Test video replay.
- [ ] Test poor light, glasses, hats, beard changes, and multiple faces.
- [ ] Review false-accept and false-reject behavior before enabling any stronger claim.
