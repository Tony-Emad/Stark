# Stark threat model

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

## Protected assets

- Local identity feature prints.
- Stark authorization state.
- Any future user-provided credential secret.

## Important threats

- Printed-photo or screen-replay spoofing.
- Video replay or an attacker presenting a similar face.
- Unauthorized local access while an authenticated Stark session remains open.
- Camera permission misuse or accidental frame persistence.
- Tampered or unsigned application bundles.

## Controls in the MVP

- Face detection, matching, and liveness are separate gates.
- Liveness requires movement across a rolling time window.
- Identity records are stored in the device-only Keychain.
- Sessions auto-lock after a configurable idle period.
- The face path never directly authorizes the system login window.
- Developer distribution is separated from local ad-hoc signing.

## Known limitations

The MacBook camera is a 2D sensor. The current Vision feature print is not an
audited biometric identity model, and the motion-based liveness check is not a
guarantee against determined replay attacks. Stark should be presented as a
convenience lock companion, not a security upgrade over macOS.
