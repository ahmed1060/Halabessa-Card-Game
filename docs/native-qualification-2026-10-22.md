# Native qualification continuation — 22 October 2026

## Baseline and scope

Active checkout: `build/lantern-remote-final`, branch
`codex/card-interaction-startup-polish`, commit `a032f765` (merged as `683d5e38`).
Android, iOS and Hosting checks on the merge commit all succeeded. The live web
player was verified byte-for-byte against the approved local export previously.

The connected Unity 6000.0.69f1 Editor targets this checkout. Its active scene is
`Assets/GameScene.unity`, clean, not playing or compiling. Initial target: WebGL;
Android export-as-project is already true; Android module is installed; IL2CPP
and ARM64 are selected. The older embedded Android export does not qualify the
new card-feedback protocol.

This continuation is local qualification, not another push or deployment.
No store upload, cloud account/room creation or live Supabase write is included.

## Protected boundary and beat sheet

No game rules, state ownership, card counts, turn deadlines, scoring, voting or
command semantics change. No animation timing or artwork changes are proposed.
The approved windup/contact/settle sequences, Flutter audio/haptic ownership,
reduced-motion paths and catch-up budgets remain exactly as implemented and
tested in the prior plan. This work verifies the native package of those beats.

Retain the optional versioned interaction handshake, identified/generation-fenced
visual completions, cancellation and snapshot fallback. ACKs remain cosmetic and
never authorize a move. Keep production interaction flags and online fencing.

## Exact file-touch map

- New documentation: this file.
- New local build adapter: `tool/native_qa.init.gradle`. Only when explicitly
  invoked with `-PhalabessaNativeQa=true`, point the local app's Unity project at
  the isolated export and restrict that QA APK to ARM64. Do not edit application
  settings or the embedded export to obtain this binding.
- New package checker: `tool/verify_native_qa_apk.ps1`, read-only verification of
  the built APK, source metadata identity, launcher/signature, ARM64-only payload,
  ZIP alignment and every native ELF load segment's 16 KB alignment. No device
  verdict is inferred from these checks.
- Generated/ignored output: `build/unity-native-qa-2026-10-22/android/`, its
  `ios/` sibling (the existing iOS module is installed), and local Android build
  outputs/artifacts. Refuse to reuse an existing export directory.
- Inspect but do not modify: `Assets/GameScene.unity`, runtime C# scripts,
  `BuildScripts.cs`, `NativeExportChecks.cs`, Android manifests/settings/build
  files, the checked-in `androidBuild/unityExport`, iOS library and web player.
- Preserve unrelated pre-existing analyzer, generated-plugin and template edits.

## Execution and acceptance

1. Record the Editor preflight and build state; dry-run the built-in live build
   command against the new output. Switch the Editor target to Android through
   Pipeline (reimport/domain reload is expected; do not save/rewrite scenes).
2. Build the current saved game scene through the live Editor into the new
   ignored folder. Require a successful report with zero errors; inspect warnings
   and current card-feedback markers in generated IL2CPP/metadata.
3. Bind only a deliberate local Gradle invocation to that export using the init
   adapter. Build the offline QA entrypoint with interaction/deck flags enabled;
   separately build the normal entrypoint with no interaction/deck defines.
   Retain the normal production entrypoint and disabled production flags.
4. Verify the actual APK's one Flutter launcher, API 24 / target 36, ARM64 Unity,
   IL2CPP and Flutter payloads, current protocol markers and signature. Report
   other ABIs as unqualified, not as supported by this ARM64 QA artifact.
5. Prepare a fresh isolated iOS Xcode project through the installed module and
   apply the existing Flutter-Unity generated-code postprocessor only inside
   that ignored output. Inspect current metadata and embedding hooks; do not
   replace `ios/UnityLibrary` or treat source generation as a Mac build verdict.
6. Restore the Editor's WebGL target and confirm its scene remains clean and
   protected tracked files are unchanged. Rollback is simply omitting the
   explicit init script; production still binds the original committed library.

Physical Android/iPhone launch, vibration, audio latency, mobile browser throttling
and subjective sound/feel approval remain separate gates. A fresh iOS Unity
export and device qualification must not be inferred from an unsigned CI build
of the older embedded iOS library. Device availability has been asked again.

## Evidence

- Merge commit checks: Android `39663098574`, iOS `39663095725`,
  Hosting `39663095820`: all completed successfully.
- Android-targeted temporary Editor harness: 8 checks passed, slam contact
  270.1 ms, full settle 488.6 ms, no scene saved. An initial immediate post-Play
  connection interruption was retried after allowing the reload to settle.
- Android export `build_1bd3da29a755`: succeeded, zero errors, three warnings
  (runtime automation disabled, automatic NDK template insertion, existing
  unused debug-console field). The inserted template line was removed and the
  source hash matched Unity's pre-export backup exactly; generated backups were
  moved into the ignored QA folder. The export's Unity API JAR matches the
  committed JAR. IL2CPP metadata includes `UNITY_CARD_FEEL_READY`,
  `HAND_SELECTION`, `VISUAL_CONTACT` and `VISUAL_ACTION_COMPLETE`.
- The initial APK build adapter was corrected to ignore Flutter's included
  Gradle build when checking its explicit opt-in. PowerShell entrypoint arguments
  were then quoted as array elements. The fresh IL2CPP compile/build succeeded
  in 8m24s, 375 tasks. The first built artifact exposed two extra datastore-only
  ABIs, correctly rejected by the package verifier. It is preserved as
  `halabessa-native-card-feel-2026-10-22-unqualified-multi-abi.apk`. Restricting
  the completed Android DSL (rather than its early defaults) corrected this
  QA-only issue; the incremental rebuild succeeded in 1m9s, 371 tasks.
- Interaction QA APK:
  `build/local-android-tools/artifacts/halabessa-native-card-feel-arm64-2026-10-22-debug.apk`,
  238,804,016 bytes, SHA-256
  `e7ffaa7eec8ad748d657b91aa08ad41eaa36da3a53a783c3e64327b3c05dc68f`.
  It uses the offline QA entrypoint with both opt-in flags. Actual package checks
  pass: application ID `com.halabessa.game`, exactly one MainActivity launcher,
  API 24 / target 36, vibration permission, signature, ARM64 only, ZIP 16 KB
  alignment and all eight native ELF libraries' load-segment alignment. Packaged
  metadata exactly matches the fresh export and includes the current protocol.
- Normal-entry APK: build succeeded in 1m14s, 371 tasks, no opt-in defines.
  `build/local-android-tools/artifacts/halabessa-native-normal-entry-arm64-2026-10-22-debug.apk`,
  261,988,096 bytes, SHA-256
  `0741dc168b8533e318d2f3b3ef80f41a3c78612a7cbf02ee23dada917a4bca64`.
  It passes the same package/ELF checks, contains `lib/main.dart` and excludes
  the offline QA entrypoint. Neither APK was installed. Both are debug-signed
  test artifacts using the normal application ID, not store releases; plan any
  installation on a test device to avoid replacing a valued primary install.
- iOS source export `build_182b21869de2`: succeeded, zero errors, two warnings
  (runtime automation disabled and existing unused debug field). Applied the
  existing Flutter-Unity generated-code postprocessor only inside this ignored
  export. Current protocol markers and native message/scene callbacks are
  present; Data references are relative; no duplicate Firebase Swift package was
  found. This is source generation, NOT an Xcode compilation or installed app.
- Static startup observation: the legacy postprocessor looks for
  `startUnity:` while Unity 6 generates `startUnity` without an argument, so its
  optional `UnityReady` notification insertion does not match. The current
  Flutter plugin also calls the completion directly after `initUnity`, so this
  is NOT established as a launch/freeze defect. No speculative runtime or
  exporter-source change was made. A Mac/device test must exercise first load,
  readiness and resume before deciding whether a correction is necessary.
- Restored Editor target: WebGL; stopped Play Mode, clean game scene, unchanged
  export-as-project setting. The Android template still matches its pre-export
  backup hash. `git diff` confirms no changes to committed Android/iOS players,
  web player, saved game scene or runtime C# scripts. Existing unrelated edits
  are preserved. Native entrypoint regression tests: 2 passed.

## Remaining acceptance gates

- Android test-device installation, one-icon/normal startup, foreground/resume,
  actual long-press vibration, tactile card cues and audio latency. ADB reports
  no connected device. New feature use limits and private/public behavior still
  require the planned user feel review, not just package inspection.
- Mac/Xcode integration/build of this NEW iOS export, then iPhone launch, audio
  session, readiness/resume and haptics. Earlier CI success used the older
  committed export and does not qualify the newly generated source.
- Throttled physical mobile-browser checks, subjective Foley sample approval
  and final user visual/feel approval. Procedural fallbacks are not represented
  as recorded/licensed Foley or as a physical-device result.
- No further commit, push, merge, deployment, app-store upload or live backend
  write occurred in this continuation. No production flags were enabled.
