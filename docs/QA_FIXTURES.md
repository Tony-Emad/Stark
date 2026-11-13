# Stark QA fixtures and manual release matrix

The automated suite validates policy and packaging behavior. Camera spoofing
cannot be represented honestly by synthetic unit tests, so these cases remain
manual release gates:

1. Enroll the owner in normal indoor light and confirm all guided poses save.
2. Try a printed photograph, a phone-screen photo, and a prerecorded video.
3. Repeat with poor light, glasses, a hat, beard changes, and a second person
   in frame.
4. Deny camera permission, use **Open Camera Settings**, grant permission, and
   confirm the scan resumes without restarting the Mac.
5. Repeat using an external camera and an Intel Mac.

Record the Mac model, macOS version, camera, result, and any false accept or
false reject in the release issue before making a public security claim.
