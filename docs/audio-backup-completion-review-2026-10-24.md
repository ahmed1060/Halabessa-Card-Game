# Audio backup completion and Android handoff — local only

## Completed source work

- Extracted the existing trusted upload operation into `asset_upload.ts`; the
  Edge entrypoint still performs the existing verified admin admission. The
  service-role credential stays server-side. No rules/claims/auth were loosened.
- New SFX/music uploads use server-generated UUID versions under
  `audio/{kind}/{slot}/v2/{uuid}.{extension}` and `x-upsert: false`. Collision,
  upload failure and concurrent replacements cannot overwrite a saved waveform.
  Existing avatar and store-item path behavior remains intact.
- Audio inputs must match one of the 16 configured logical routes and a supported
  audio MIME/container header within the existing 4 MB limit. Header checks do
  not certify complete codec decodability; actual preview handles decode errors.
- Saved defaults/restores now use a narrow Firestore store and atomic transactions
  reading the committed document, not the potentially stale screen snapshot.
  Explicit bundled reset remains independent of remote saved-default URLs.
- Both actual admin upload controls use a tested upload-then-publish coordinator.
  Failed upload never publishes a pointer; failed config save leaves the previous
  pointer intact. The newly uploaded unreferenced object is retained rather than
  risking deletion of a saved object. No automatic destructive cleanup was added.
- UI upload requests are guarded against duplicate picker launches and safely
  return when the screen closes. File picking and storage are injectable for
  complete local screen interaction tests without real dialogs/cloud accounts.

No gameplay, turn/scoring rules, audio contact timing, bridge, haptics, Unity source,
shipping application ID or production feature flag changed during this continuation.

## Verification

- **657 Flutter tests passed** with the local interaction/refinement flags.
- **223 Edge adapter tests passed**, including the seven new storage tests.
- **6 dedicated Firestore emulator audio tests passed**, using only
  `demo-halabessa-audio` on loopback. Admin save/replace/restore/bundled reset,
  missing-backup reset and preservation of unrelated settings passed. Ordinary,
  anonymous and deletion-blocked accounts were rejected by the real rules.
- The complete updated Firestore/Realtime Database emulator suite also passed:
  **42 tests**, including the new audio tests and existing profile, room and
  orientation authorization tests. All emulators were stopped afterward.
- The actual upload implementation was exercised over a real loopback HTTP
  connection to a fake Storage protocol endpoint: concurrent B replacements left
  saved A's bytes unchanged, and deliberate version collision failed closed.
- Real Flutter SFX/home/room upload-button tests passed through a fake file picker
  and local upload/save adapter, including error recovery and no-save-on-failure.
  These are local test doubles, not claims of real production admin uploads.
- Complete Edge entrypoint typecheck passed using CI's Deno 2.5.4. Scoped Dart
  analysis reported no issues. New storage and rules tests were added to CI's
  existing test lists, but no remote Action was triggered by this work.
- The first Firestore emulator launch failed in Windows Java's Unix-domain
  loopback creation. A process-only short socket/temp directory fixed it; no
  global Java/network/security setting was changed. Emulators shut down after tests.

## Android artifact

Prepared a **separate** debug test application, not a replacement for the player's
normal app:

- Name: **Halabessa Audio QA**.
- Application ID: `com.halabessa.game.audioqa`; launcher: one Flutter MainActivity.
- APK: `build/local-android-tools/artifacts/halabessa-audio-qa-arm64-2026-10-24-debug.apk`.
- Size: 240,189,081 bytes.
- SHA-256: `352ff5ae9da749cdd498a3c8a16a7aec1cc27da2f3300a595d09366493daa270`.
- ARM64 only, API 24 minimum / target 36; signature, ZIP and native ELF 16 KB
  alignment verified. Vibration permission is present. All 16 audio routes match
  the selected bundled file bytes by SHA-256.
- Build succeeded in 1m52s using explicit local init scripts. Normal builds do
  not load those scripts; the normal application ID and launcher remain unchanged.

This audio/Flutter-interaction QA artifact reuses the existing isolated Android
Unity export from **22 October**. It does not claim to contain a newly rebuilt
24 October Unity renderer. Newer native visual refinements still require their
own fresh export/device qualification. The existing web player was not replaced.

The user reports an Android phone is available, but ADB currently lists no device.
The APK has **not been installed**, no app data was cleared, and no device launch,
physical vibration, audio latency, foreground/resume or subjective sound result
is claimed. Connect/unlock the phone, enable USB debugging and accept the PC's
debugging prompt before device-specific inspection/installation can continue.

## Remaining external gates

1. Android connection, safe test install and hands-on launch/audio/haptic checks.
2. A Mac with Xcode/iPhone for native iOS compilation/installation and audio session,
   launch/resume and haptic checks; no such runtime/device evidence is available.
3. Real production admin upload/restore requires explicit authorization and the
   backend fix to be deployed. It was not performed as a substitute for emulation.
4. User approval before any push, merge, function/hosting deployment or store upload.

No commit, push, deployment, live storage write, live settings mutation, deletion,
uninstall or publishing occurred. Previously overwritten legacy audio cannot be
reconstructed from a URL; the chosen bundled defaults remain the recovery source.
