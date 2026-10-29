# Local Unity export integration

Baseline: development, with the separate birthday/UTF-8 and tested LAN adapter
changes preserved. The reviewed source is exported under
build/lan-release-candidate-final-2026-10-28. The previous batch built an Android
APK from the same staged bytes and qualified complete LAN matches. Shipping
paths still contain the older players; iOS has stale Unity Firebase scaffolding.

## Protected boundary and appearance

No gameplay, authoritative command, timer, card-count, bot, voting, score,
economy, audio choice or production gesture flag change. Current Unity and
Flutter motions, contact/settle durations, easing, reduced-motion behavior,
audio/haptic ownership and catch-up budget remain unchanged. Existing optional
readiness/viewport bridge messages and fallback remain exactly as tested. This
is packaging integration, with no new visual beat or renderer adapter.

## Exact file map

- Add tool/integrate_unity_release.mjs and its Node tests. Verify the staged
  manifest first, archive the three old export directories under a new ignored
  build/unity-export-integration-2026-10-28 directory using checked absolute
  paths, then copy the staged Android unityLibrary, iOS project and web Build.
  Preserve old exports and metadata for rollback; no recursive deletion.
- Normalize only the generated iOS project's unused Windows symbol-tool option
  (reject unexpected/symbol-generation configurations). Retain relative Data,
  native integration hooks and UnityFramework target. Do not change Unity source.
- Update ios/Podfile to remove the obsolete Unity Firebase target, retaining
  FlutterFire's existing SDK pin and the resource-only privacy-target fix.
- Align android/app/build.gradle's ABI filter with the existing ARM64-only
  Unity export. Normal packaging verification exposed extra Flutter-only ABIs;
  the prior QA ABI override hid that mismatch. Add its source contract to
  functions/test/native_entrypoints.test.mjs and recheck the resulting APK.
- Add UnityFramework explicitly to Runner's existing scheme build entries so
  framework compilation no longer depends on the removed CocoaPods target.
- Add unity/player-release.json and tool/verify_unity_players.mjs plus tests:
  hash source and integrated payloads, reject stale/LFS placeholder binaries,
  validate native capabilities and iOS integration contracts before builds.
  Update tool/verify_native_qa_apk.ps1 to compare APK metadata with that integrated
  shipping player and require the two newly qualified bridge capabilities.
  Ignore native working caches and disable whitespace diagnostics only for
  verbatim generated IL2CPP C/C++, whose complete payload hashes remain checked.
- Update web/unity-release.json and only its two stable identifiers in
  web/index.html, retaining the current loader/startup/fallback mechanism.
- Extend android-build.yml, ios-build.yml, web-card-gestures.yml and
  firebase-hosting-merge.yml with the applicable player verification step.
  Replace iOS's obsolete assertion requiring Unity Firebase frameworks with
  absence checks; retain FlutterFire lock checks and Xcode requirements.

GameEngine, LAN authority/transport, Flutter presentation, Unity scripts/scenes,
user data, backend, sound assets, native release flags and toolchain versions are
inspected/preserved, not edited by this integration.

## Verification and rollback

Run transformation/negative guard tests, native entrypoint and existing web
release regressions, check source/payload hashes, compile the actual Android app
without the QA export redirection, and build/test the web artifact. A Mac must
still compile the fresh iOS project; physical Android/iPhone same-Wi-Fi,
permissions, resume, Unity composition, sound and haptic checks remain open.
This batch remains local: no push, merge, CI dispatch, deployment or install.

The archive stores the original export roots and release metadata. Restoration
can move integrated folders to a separate ignored recovery path and move the
original directories back, then revert only this batch's small integration
edits. The existing 3D setting remains the presentation rollback to Flutter.
