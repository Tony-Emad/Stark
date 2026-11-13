# Stark privacy notice

Owner: Tony Emad  
Copyright: © 2026 Tony Emad. All rights reserved.

Stark's camera frames are processed locally for face detection, feature-print
generation, and liveness signals. Source camera frames are not intentionally
written to disk by the prototype. Derived identity records are stored in a
device-only Keychain item and can be deleted from Stark settings.

Stark does not send camera frames, feature prints, passwords, or Touch ID data
to a server. The app never receives raw Touch ID data; macOS presents and
evaluates the LocalAuthentication prompt.

The current camera matching implementation is a prototype convenience feature,
not a replacement for hardware-backed biometric security. Users can disable
camera access, delete saved identity data, or use the manual Touch ID/password
path at any time.
