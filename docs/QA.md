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
- [x] Enrollment UI exposes automatic capture instead of a manual capture button.
- [x] Camera preview uses zero-degree native camera orientation and explicitly disables video mirroring.
- [x] App launch does not show an unsolicited Keychain authentication dialog.

Run all automated checks with:

```sh
./scripts/verify_release.sh
```

## Manual Mac checks

- [x] Launch the app on this Apple Silicon Mac and confirm the panel is anchored to the top center.
- [x] Confirm Done permanently dismisses completed setup, X hides it temporarily, and Settings remains independent.
- [x] Confirm explicit Open Stark setup restores the panel at the top center.
- [x] Confirm the Settings window uses readable card sections without clipped text.
- [ ] Launch the app on an Intel Mac and confirm the panel and camera preview work.
- [ ] Deny camera permission and confirm Stark explains how to recover it.
- [ ] Allow camera permission and confirm face presence updates the scan state.
- [ ] Capture all guided poses automatically and confirm samples persist after relaunch.
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
