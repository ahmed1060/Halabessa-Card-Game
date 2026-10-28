# Native and browser qualification — 26 October 2026

Baseline: development/main release 8acf7222, clean root checkout. Unity 6000.0.69f1 is connected to unity/Halabessa, WebGL active, GameScene clean, not playing/compiling. Android/iOS modules are installed; Android export is already enabled and ARM64 is selected.

Local qualification only. Export current source to new ignored build/native-qualification-2026-10-26/android and ios folders through the connected Editor. Use the existing build pipeline and iOS generated-code postprocessor only in those outputs. Do not invoke the older integration exporter that replaces embedded Flutter libraries. Restore Editor target WebGL afterward; compare tracked scene/settings/template hashes and inspect the diff. No rule, timer, score, command, audio choice, bridge contract or motion timing change.

Approved presentation windup/contact/settle times and Flutter audio/haptic ownership remain unchanged. Native build reports establish source/export compatibility only; no phone is connected, and Windows cannot compile/install the generated iOS project with Xcode.

Inspect generated metadata/capability markers and package preparation. If compatible, prepare local test artifacts without replacing a primary install, signing into cloud accounts, enabling production native gesture flags or publishing. Existing shipping-player rollback remains intact because tracked Android/iOS players are not replaced. No new adapter or bridge event is introduced.

Browser review uses the already compiled release-source local fixture, including actual-width checks and no cloud writes. Physical keyboard/haptic/touch behavior and real multi-account cloud messages remain separate acceptance checks.

## Live-review finding and scoped correction plan

The live Quick Chat catalog loads through the real superadmin route, but Arabic text is mojibake. The bundled fixture and translations render correctly. The installed http package defaults response.body to Latin-1 without charset; the API sends UTF-8 JSON bytes with application/json only.

Change lib/core/services/backend_transport.dart to decode JSON response.bodyBytes explicitly as UTF-8, retaining invalid-body failure handling; change supabase/functions/halabessa-api/index.ts response Content-Type to application/json; charset=utf-8 for old clients. Extend test/backend_transport_test.dart with real UTF-8 response bytes (bare JSON, explicit charset, absent Content-Type, Arabic errors and invalid UTF-8). No UI, animation timings, authorization, retries, API actions or saved data changes. Verify failing reproduction first, then focused/full tests and Deno check. Keep this follow-up local until separately published; rollback is these two decoding/header changes.

Local APK preparation reuses ignored copies of tool/native_qa.init.gradle and tool/verify_native_qa_apk.ps1, adjusting only their isolated export path and checkout root. The tracked helpers remain unchanged. Build the normal entrypoint as an ARM64 debug-signed QA artifact with the three existing gesture flags; do not install it or replace a primary app. Verify its one launcher, ABI/alignment, signature and exact fresh-export metadata before device testing.

## Results

- Connected Editor exported current Android source successfully: 86.321 seconds, zero errors, three warnings. iOS export succeeded in 101.660 seconds, zero errors, two warnings. Full reports are preserved in ignored build/table-social-ui-2026-10-25/{android,ios}-native-export.json.
- Editor target was restored to WebGL. Scene, ProjectSettings and original Android template hashes matched the pre-export manifest. Automatic Unity template changes were restored from the hash-verified backup; generated sources remain isolated under build/native-qualification-2026-10-26.
- Android metadata SHA256: 83b5eb4330232648bb694467ddd66ccf852723a3b868bf9425c7e8cb6934de37. iOS metadata SHA256: 4ff29740b89eefbea3486bc295c438bc80048ddfbf0f77396a04a292b2abfe18. The generated iOS output received the existing Xcode postprocessor; Windows cannot compile it with Xcode.
- The local Android normal-entry APK build succeeded using installed Gradle 8.14.5 and project JDK 21. The short JDK Unix-domain temporary path resolved Windows loopback setup; normal repository resolution supplied the uncached AndroidX version listing. No global Java configuration changed.
- Preserved APK: build/native-qualification-2026-10-26/halabessa-native-current-arm64-debug.apk, 240262341 bytes, SHA256 d3433cbe3c4dcfbb8e9f9d61119dc427f20825845fc3afdccf73bc08f40c2c95.
- Verification passed: package com.halabessa.game, minSdk24/targetSdk36, exactly one launcher (MainActivity), ARM64 only, debug signature, 16KB ZIP and ELF alignment, current bridge protocol and exact fresh Unity export metadata. All 14 bundled default WAVs match their source bytes. These checks do not establish audible playback or physical haptics.
- No APK was installed, no shipping Unity library replaced and no native production feature flags enabled. Phone launch/resume, touch gestures, audio/vibration and iPhone/Xcode checks remain open. The live multi-person chat acceptance test also remains open; this session had one signed-in account and sent no real group messages.

UTF-8 transport verification: the new real-byte regressions reproduced the old decoder failure; the corrected transport passed 29 focused tests and 306 backend tests before the subsequent landing-test replacement. With the birthday/direct-entry patch the backend suite passes 298 tests. Arabic catalog text was inspected and cancelled on the live site; no garbled phrase was saved. The client/header fix remains local until a separate release.
