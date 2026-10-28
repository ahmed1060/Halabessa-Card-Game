# Unity export integration — 28 October 2026

Local development integration. Nothing committed, pushed, merged, deployed or
installed. This review supersedes the shipping-player promotion gate in the
earlier LAN qualification review; device and Mac qualification remain separate.

## Integrated players and recovery

The verified candidate now supplies androidBuild/unityExport/unityLibrary,
ios/UnityLibrary and web/Build. Release identity:
`lan-unity-20261028-548d2ccbc40a`.

Original export directories were moved intact to the same relative paths under
ignored build/unity-export-integration-2026-10-28. No recursive delete was used.
Absolute source/archive paths were checked before every directory move; the
recovery.json journal records all three completed moves and copies. Original
web metadata/index and iOS integration files are also retained in
integration-files. The previous APKs, isolated exports and branch-consolidation
archives remain available.

The large generated diff is expected: Android now consumes the precompiled
player without the Windows IL2CPP compiler, and fresh iOS generated code no
longer includes the obsolete Unity Firebase integration. Unity source, scenes,
rules, commands, timers, scores, sound choices and gesture release flags were
not changed in this batch.

## Build integration

- Removed iOS's obsolete UnityFramework Firebase CocoaPods target; retained the
  FlutterFire SDK pin and the resource-only privacy target fix.
- Runner's scheme explicitly builds the real UnityFramework target while still
  launching Runner.app. Its target ID and project reference are checked. This
  uses the existing workspace and implicit dependency handling, consistent with
  [Apple's scheme documentation](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project?changes=_6).
- Removed exactly one unused Windows symbol-tool option from the generated
  Xcode project. The transformation rejects symbol-generation configurations or
  unresolved machine-specific paths rather than silently stripping required tools.
- The normal Android build exposed extra Flutter-only ABIs despite the existing
  ARM64-only Unity export. android/app/build.gradle now restricts the app to that
  supported ABI; a native entrypoint regression checks the app/export agreement.
- Updated the existing web release manifest and its two stable loader IDs. The
  loader, startup, fallback, SEO and earlier birthday/direct-entry edits remain.
- Added unity/player-release.json and verification before Android/iOS CI builds,
  web validation and Hosting release. The guard checks all 781 Unity source files
  and platform payload identities, required bridge capabilities, LFS resolution
  and iOS integration. It reports physicalDevices=false and xcodeCompiled=false.

The source fingerprint is observed at staging, not a retroactive signed export
attestation. The manifest retains that limitation. It prevents later source or
payload drift from silently building an older player; uncertain provenance
requires another connected Editor export.

Native working caches are ignored. Generated IL2CPP C/C++ retains the exporter's
whitespace verbatim; only that generated source tree disables Git whitespace
diagnostics. Complete file hashes still guard those artifacts. Handwritten files
remain subject to normal diff checks.

## Verification

Integrated source/payload verification passed 3,930 file checks. Transformation
and guard tests cover stale/added source, changed binaries, unresolved LFS
pointers, platform isolation, missing/wrong Unity target, Windows paths,
unsupported symbol-generation settings and checkout line-ending conversion.
The final focused Node run passed 33 tests. After the late Android ABI setting
was corrected, all nine affected native/integration contracts passed again.
Handwritten diff checks passed; generated whitespace is handled as described above.

The actual web release compiled in 288.7s and its four Unity payload hashes match
the integrated manifest. Flutter entrypoints remain main.a793b100eb850ec2.dart.js
and flutter_bootstrap.d7fffbd5ef3d1c0e.js; 78 artwork references were fingerprinted.
Output: build/lan-integration-web-2026-10-28. Existing plugin Wasm dry-run warnings
do not represent a Wasm build; this was the normal JavaScript Flutter release
with Unity WebAssembly assets.

Android's ordinary online build could not resolve Maven's hostname while
listing androidx.test:runner:1.2+ versions. Offline resolution also lacked the
dynamic version listing. Qualification therefore uses an ignored init script
that selects the already-cached 1.2.0 matching that test dependency's declared
range. It changes no repository dependency declaration, Unity project path or
ABI; the app's real ABI filter is now tested. CI still needs normal dependency
resolution with network access. Initial unfiltered APK verification correctly
failed its ABI check and the artifact is labeled unfiltered; do not install it.

Flutter also appends ABI defaults after the ordinary Android DSL. The app filter
therefore runs in androidComponents.finalizeDsl, clearing those defaults and
selecting the embedded player's ARM64 ABI. The final APK passes the packaged ABI
check; this is not inferred from a source-only setting.

Final integrated APK build: succeeded in 1m58s, 408 tasks, using that cached test
dependency override and the normal shipping Unity project path. Artifact:
build/lan-unity-2026-10-28/halabessa-lan-integrated-arm64-debug.apk,
250,950,703 bytes, SHA256
a75ef042feb0c52822b1a9cfea2efa141b81a1f874e27e229f5401338b9c92d2.
Verification passed exactly one MainActivity launcher, normal app entrypoint,
ARM64 only, minSdk24/targetSdk36, debug signature, ZIP/ELF 16 KB alignment and
current protocol markers. The packaged metadata and all three Unity runtime
binaries match the integrated export exactly. All 16 selected bundled sound
routes match the reviewed source bytes; audible playback is not established.
Post-build source/payload verification still passes all 3,930 checks.

Logs and reports are under build/lan-unity-2026-10-28:
integrated-apk-finalized-build.log, integrated-apk-verification-final.log,
integrated-audio-byte-verification.json, integrated-player-verification-final.log,
integration-final-node-tests.log and final-native-contract-tests.log.

Modern Web Guidance was searched for stable asset versioning and its WebAssembly
guide was reviewed. Its compiler/API recommendations do not apply to copying
already-built Unity artifacts; the existing loader/versioning mechanism remains.

An optional line-ending cleanup command was rejected by automatic approval
review because replacing a modified workflow from HEAD could discard existing
edits. That command did not run. The working files were retained. Subsequent
read-only comparison confirmed the Hosting workflow has only the intended new
verification step apart from line endings, and the web index differs from its
preserved pre-integration copy only in the two release IDs and line endings.

## Remaining release gates

Run the native CI builds with normal dependency resolution before merging a
release. On macOS, install CocoaPods and compile Runner/UnityFramework, checking
Debug, Release and Flutter Profile configuration behavior, framework embedding
and device launch. Windows source checks cannot qualify those Xcode operations.

Physical Android/iPhone same-Wi-Fi rooms, discovery/QR, first-use permissions,
background/resume, native Unity composition, gesture motion, sound and haptics
remain outstanding. No physical installation or online reward/account mutation
was performed. Prior complete-match LAN and renderer evidence remains in the
paired LAN reviews; it was not rerun or represented as mobile-device testing.
