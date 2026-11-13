# Stark security and privacy model

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Claims Stark may make

- Camera processing is local when the implementation is running in local mode.
- Touch ID/password authorization is delegated to Apple's LocalAuthentication UI.
- The Mac camera experience is a convenience feature, not hardware-backed Face ID.
- Prototype identity records are stored in a device-only Keychain item.

## Claims Stark must not make

- Stark must not claim to be equivalent to Apple's Face ID or Touch ID.
- Stark must not claim that a camera face match directly authorizes the macOS login window.
- Stark must not treat the current Vision feature print as a final biometric model.
- Stark must not store passwords in plaintext, logs, analytics, crash reports, or ordinary files.

## Required protections

- Encrypt derived identity data at rest.
- Gate credential-key access with Keychain and recent user authentication.
- Expire authorized sessions after a configurable idle period.
- Make camera, Accessibility, and credential features independently revocable.
- Provide an always-available manual recovery path.
- Record security events without biometric data or password content.

## Release review

Before a public release, Tony Emad should review false-accept risk, false-reject
behavior, privacy strings, entitlements, third-party licenses, code signing,
notarization, and the uninstall/data-deletion flow.
