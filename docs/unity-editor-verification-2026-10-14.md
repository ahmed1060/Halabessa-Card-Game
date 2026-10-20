# Unity Editor qualification — presentation only

Latest local review status: [2026-10-15 playable preview](local-playable-preview-2026-10-15.md).
It supersedes the older input/HUD qualification notes below: 514 Flutter tests,
49 Editor checks, a refreshed isolated WebGL export, and full-HUD local browser
input/portrait/landscape evidence. No commit, push, deployment or native promotion.

Date: 2026-10-14. Active checkout: `build/lantern-remote-final`, branch
`codex/option-b-final-layout`, baseline `b41275f4720649e2c008a5bc9d0c795bea69c58b`.

## Approved tooling

The user installed Unity 6000.0.69f1 with Android, WebGL and iOS support and
explicitly approved official Editor automation. Unity CLI 1.0.0-beta.13 and
`com.unity.pipeline@0.8.0-exp.1` are installed. The package was added with Unity's
PackageManager Client API, not by hand-writing the manifest. Local Editor
automation uses loopback; no production/backend service was configured.

Package resolution added Mono.Cecil 1.11.6, Newtonsoft JSON 3.2.1, the built-in
Test Framework 1.6.0 and NUnit 2.0.5. Unity warns that the newer Newtonsoft
assembly supersedes the existing FlutterUnityIntegration/AOT assembly. That
legacy DLL was not deleted or disabled. Native export qualification remains a
separate gate. Pipeline is experimental and its dependency diff is separate
from game-presentation changes. No RuntimePipelineConfig was added: the clean
export warns explicitly that Pipeline is disabled in Player builds. No runtime
automation server was enabled.

`Assets/Editor/HalabessaQa/EditorPackageSetup.cs` contains explicitly invoked
package installation, isolated web export and saved-build-report readback only;
it neither autoruns nor ships in players. Readback uses Unity's official
[BuildReport.GetLatestReport API](https://docs.unity3d.com/ja/6000.0/ScriptReference/Build.Reporting.BuildReport.GetLatestReport.html).
`AgentScripts/CardJuiceSmoke.cs` and
`AgentScripts/VisualBuildCheck.cs` are outside Assets and run in memory through
Pipeline. They do not rebuild or save scenes, or modify embedded app exports.

## Live findings fixed

| Finding | Surgical presentation/input fix |
| --- | --- |
| Existing saved scene lacked pointer dispatch for 3D cards. | Add an EventSystem/input module only when absent, and a camera PhysicsRaycaster only when absent, at runtime. Scene YAML remains unchanged. |
| Hard-coded legacy drop Z threshold rejected the measured landscape table. | Use measured viewport table/hand separation for the negotiated visual renderer; retain legacy threshold otherwise. Flutter still validates the same PLAY_CARD intent. |
| DragMe resource key was wrong, and its Awake ran before configuration assignment. | Load the existing resource first and configure the component while the card is inactive; no third-party library rewrite. |
| Rigidbody/DragMe desired position fought new visual flight/snapshot positions. | Synchronize those presentation positions through CardInstance, without changing card ownership or rules. |
| Cancellation during collection left shrinking roots and orphan tweens. | Track/kill the collection sequence, restore snapshot pose and root scale, and cancel child effects. |

Affected runtime scripts remain `UnityBridge.cs`, `CardInstance.cs`, and the new
`CardJuiceController.cs`. Flutter domain, backend, saved GameScene and CardPrefab
diffs are empty. No rule, score, winner, bot, voting or authoritative deadline
change was used to improve pacing. Approved Option B Flutter coordinates remain.

## Evidence

- Actual Editor compile before/after Pipeline installation passed:
  `build/unity-card-juice-compile.log` and
  `build/unity-card-juice-compile-with-pipeline.log`.
- **28 live Editor fixture checks passed**, with no unexpected exception/assert
  or orphan tween warning: `build/unity-card-juice-smoke.json`.
  They cover public/local card membership, portrait/landscape drop separation,
  pointer infrastructure, configured DragMe, root-stable 1.2x peek/sorting,
  single contact, capture hold/collection, camera restoration, bounded particles,
  stale generations, reduced motion, mid-collection cancellation, invalid return,
  and unchanged legacy game-state value.
- **24 Flutter follow-up tests passed**:
  `build/card-juice-editor-followup-flutter-tests.log`. Earlier full-suite and
  rollback results remain **511** and **55** passes respectively.
- The isolated Unity WebGL build completed: `Build Finished, Result: Success`
  in `build/unity-card-juice-live-editor.log`. Output is
  `build/unity-spices-qa/web`, not the embedded Flutter UnityLibrary.
  The live request timed out after 540 seconds while Unity continued compiling
  and compressing. A timeout response is not treated as a successful build;
  the later Editor result/output and saved BuildReport establish completion.
  Saved report readback: `build/unity-card-juice-web-build-report.json`.
- A dedicated cached batch export then passed with exit code **0**, BuildResult
  **Succeeded**, **0 errors**, **1 warning**, and **9,678,317 bytes** of output:
  `build/unity-card-juice-web-batch.log`. The only build warning says Pipeline
  is disabled in Player builds because no runtime configuration exists. This
  clean batch result supersedes the live build's two timeout-related errors,
  which were counted despite that earlier export completing. The final saved
  BuildReport JSON contains the clean batch result and warning text.
- The first export attempt was made with the wrong active target and failed
  resolving WebGLInput. Selecting WebGL and finishing its domain reload fixed
  the QA setup; no speculative namespace/API change was made.
- C# syntax and scoped CR-at-EOL diff checks pass. Pre-existing analysis and
  generated platform registrant changes are preserved.

The hidden resident QA Editor was closed after the build and a batch readback
restored the original Windows build target. User Unity Hub was not closed.

## Remaining gates

1. Browser/Flutter end-to-end qualification of the isolated WebGL renderer,
   including actual card art, input, mute, reduced motion and lifecycle recovery.
2. Isolated native exports and Android/iPhone portrait/landscape device checks:
   genuine finger input, HUD/board cohesion, latency, frame pacing, haptics/audio
   synchronization, background/reconnect and dependency overlap.
3. Native round-win particle references in the saved scene are unassigned;
   the tested slam burst is separate. Do not equate that with working native
   round-win confetti or change winner logic to produce an effect.
4. iOS final build/signing needs Mac/Xcode or an appropriate build service.
5. Only after qualification should embedded exports be replaced and a release
   promoted. This pass made no commit, push, deployment or live-account mutation.

Editor fixtures and Flutter widget tests are not device or shipping proof.
Rollback remains `--dart-define=HALABESSA_CARD_JUICE=false`, which restores legacy
presentation paths without changing rules or resetting any player or room.

## Browser and native follow-up

The user authorized continuing qualification, confirmed no Android phone or
Mac/Xcode is available now, and separately approved repairing the existing
dangling scene root `293843866` after the Android export reported it as an error.

The repair ran through the live Editor, with a backup at
`build/unity-scene-before-root-repair.unity`. Its saved diff removes **exactly
one SceneRoots entry**. All seven real roots and their serialized component
values were unchanged. Evidence: `build/unity-scene-root-repair.json`.
This is the only scene change; the earlier statement that scene diffs were empty
describes verification before this explicitly approved follow-up.

| Follow-up | Result and limits |
| --- | --- |
| Real Flutter-to-WebGL fixture bridge | **12 checks passed**, including contact/ACK, unchanged capability (no timeout fallback), private-hand filtering, generation fencing, invalid return dispatch and reduced-motion completion. Ordinary ACK was about 372 ms and capture ACK about 1440 ms in this desktop run. |
| Android Unity export | **Succeeded, 0 errors, 1 warning**; generated Gradle/IL2CPP project at `build/unity-spices-qa/android`. This is not a compiled Flutter APK or an installed device test. |
| iOS Unity export | **Succeeded, 0 errors, 2 warnings**; generated Xcode/IL2CPP project at `build/unity-spices-qa/ios`. Existing FlutterUnityIntegration Xcode post-processing ran; this is not a signed IPA or Xcode/device compilation. |

Native reports: `build/unity-card-juice-android-export.json` and
`build/unity-card-juice-ios-export.json`; CLI build provenance is saved beside
their logs. Pipeline remains disabled in players. iOS additionally reports an
existing unused debug-console field. No app embedding paths were overwritten.
Unity automatically inserted an `ndkPath` line into the Android source template
during export. That task-generated insertion was removed after qualification
to preserve the project's existing portable template. Unity's generated backup
and its metadata are retained under `build/unity-spices-qa/template-backup`,
not inside the shipping Assets tree.

The local-only entry point `tool/unity_browser_qa.dart` reuses the production
UnityVisualPresentation adapter, web registry and host bridge with fixed
accepted-state fixtures. It initializes no account, Firebase session, database
or match command. Its build is `build/card-juice-hybrid-qa`; the standalone
WebGL artifact was copied only into that QA build. Dart analysis is clean and
the Flutter release QA build succeeds. The origin guard is strict same-window,
same-origin and uses the existing tuple-origin channel; no new origin API or
Emscripten wrapper was imposed. It does not certify the full GameBoardScreen,
phone input, audio/haptics or online networking.

### Blocking visual finding — do not promote the native renderer

Despite the real contact/ACK tests passing, the browser canvas was black with
no visible cards. Read-only Editor inspection confirms:

- `DeckManager.availableSkins` is empty in the saved GameScene.
- CardPrefab's default Standard material has no texture.
- The Quad mesh normal is `(0, 0, -1)`; the existing bridge's `-90` table and
  `-60` hand rotations make their front faces point away from the actual camera.
- CardInstance exists, and runtime logs confirm cards were spawned. This is not
  proof that their artwork is visible.

Source/Editor evidence: `build/unity-visual-asset-audit.json`; visual evidence:
`build/unity-browser-qa.jpg`. The audit left the scene clean. These pre-existing
renderer prerequisites were not silently replaced with invented art or an
unapproved scene rebuild. Completing rank-specific front art/back skins and
correct facing is a **separate presentation integration step**, not merely
timing tuning. Obtain direction for that expansion before replacing embedded
exports. Flutter 2D presentation remains available; no native visual-release
claim is made here.

### Approved artwork and facing follow-up

The user authorized repairing these presentation prerequisites. The offline
`tool/export_unity_card_art_test.dart` renders the existing production CardWidget,
fonts and licensed project artwork: 52 rank-specific faces plus a back for each
of default, neon and royal skins (159 PNGs). It initializes no live account or
remote store listener. `AgentScripts/ImportCardArtwork.cs` imports these through
the Editor into Resources and generates the shared 70:100 mesh and transparent
material. No CardPrefab, scene hierarchy or gameplay data was replaced.

CardInstance owns its runtime face/shadow materials, uses the same geometry for
its collider, and destroys only owned material instances. DeckManager retains
configured custom skins, with rank-specific Resources fallbacks for the three
existing built-in skins. UnityBridge now uses camera-facing positive pitches.
The browser now visibly renders actual ranks and court artwork on first load.

The first-load bridge race was also reproduced: Unity's READY callback can precede
resolution of the loader Promise. The host now buffers up to eight validated
same-window/same-origin messages while starting, flushes in order, and uses the
existing Flutter fallback on overflow. `tool/unity_web_host_test.cjs` covers the
guards, startup snapshot, normal delivery and bounded fallback.

The browser alpha diagnostic confirmed context alpha support but an opaque empty
pixel (255). A QA-only GL trace identified Unity's final default-framebuffer
alpha-only clear, not a CSS background. An SDR camera trial did not resolve it
and was removed. `HalabessaTransparency.jslib` is explicitly opted in by the
host and skips only the opaque, alpha-only default-buffer clear. Normal RGB,
camera/depth clears, offscreen buffers and unopted hosts remain unchanged.
`tool/unity_transparency_test.cjs` verifies those boundaries. The diagnostic
trace is QA-only and must not be included in shipping host builds.

Trace evidence: `build/unity-alpha-trace.json` records repeated default-buffer
clears with RGB writes disabled, alpha writes enabled and clear alpha 1. This
overrides the camera's zero-alpha background. The existing
[preserveFramebufferAlpha setting](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/PlayerSettings-preserveFramebufferAlpha.html)
applies to native targets, not WebGL; it was already enabled and was not changed.
The guard is present in the newly linked Emscripten output, not merely in a
JavaScript unit-test fixture. It does not colour-key black card pips.

Small native table groups now have full-face spacing. Dense groups over four
cards retain their previous stacked layout and require a separate readability
review; this is not a claim that all native layouts are qualified.

Artwork/export regression evidence: one offline bake test and 25 Flutter
regression tests passed. The tooling entry points analyze without issues. The
updated export reports and final browser/Editor results below supersede earlier
artifact counts; nothing has been copied into the app embedding paths.

The final real-frame Editor fixture passed **37 checks**, recorded in
`build/unity-card-art-deferred-smoke.json`. Repeated fixtures now use a fresh
renderer generation rather than reusing a stale fixed ID. Direct pointer
callbacks temporarily isolate the EventSystem; original pointer processing is
restored. The fixture enables background ticking only in its QA Play Mode session
and restores it, with no PlayerSettings edit. An initial unfocused run recorded
zero game frames despite wall-clock time advancing; those failures are not
animation qualification. WebGL-selected Editor Play Mode also exposed a legacy
FlutterUnityIntegration native-call guard issue; the wrapper was left untouched,
and Editor fixtures used the original Windows target. Actual WebGL player builds
and browser tests remain separate evidence.

### 2026-10-15 skin and real-input review

Read-only review found that GetActiveSkin's first-configured fallback could
override an explicit built-in selection. GetSkinForCard now distinguishes an
exact configured selection from that fallback. Two added Editor fixtures verify
both built-in precedence and preservation of an exact custom skin. No equipped
item ownership, store data or unlock logic was touched.

Final isolated export snapshot: WebGL succeeded with 0 errors, 2 warnings,
15,628,451 bytes; Android succeeded with 0 errors and 2 warnings; iOS succeeded
with 0 errors and 2 warnings. The warnings are disabled-in-player Pipeline
configuration and the existing unused debug-console field. These exports precede
the final skin-precedence correction; that correction has real Editor compilation
and fixture evidence, not a refreshed mobile/WebGL export yet. Re-export after
the remaining input work before considering promotion. No embedded paths changed.

The transparent browser canvas now preserves empty pixels at alpha 0. An early
300 ms measurement sampled the startup splash fade (alpha 25); the QA tool now
measures the finished scene, including immediately before assertions. The
portrait replay passed 14 checks at 430x932 with visible rank-specific cards.
The fixture is not the full game HUD and does not certify native card sizing.

The foreground landscape replay at 932x430 also passed **14 checks**, with no
browser warning/error entries. Ordinary completion measured 378 ms; collection
completion measured 1450 ms in that desktop run. Evidence:
`build/unity-card-art-browser-portrait.jpg`,
`build/unity-card-art-browser-landscape-pass.jpg` and
`build/unity-card-art-browser-console.json`.
An earlier landscape run was interrupted while the Editor took focus and hit
the fixture's four-second timeout; its screenshot remains at
`build/unity-card-art-browser-landscape.jpg`. The foreground pass is not proof
of production background/resume behavior. The temporary browser viewport was
reset after testing.

Direct browser presses on card artwork produced VISUAL_PICK. **No successful
real browser drag/drop is claimed.** Inspection found that the runtime-created
DragMe component in CardInstance.SetupDragging wires e_Released but not the
library's GrabMe/MoveMe actions. DragMe.Start.RegisterEventListeners is empty;
TryGrab/TryDrag emit events and rely on those actions for movement. This is a
pre-existing native input prerequisite, not a rules/pacing change. Do not silently
replace the input implementation under the spices-only pass. A scoped repair
must retain Flutter intent validation, local-hand-only interaction, one command
per release, invalid-drop return and legacy fallback behavior.

The saved scene layout still has unassigned native round-win particle references;
dense table groups over four cards and full Option B native sizing remain review
gates. Physical device input, audio/haptics, background/resume and iOS signing
remain unqualified. The original Windows Editor target was restored and only the
task-owned Editor was closed. Exporter-generated Android template backups are
recoverably retained outside Assets; no player or account records were deleted.
