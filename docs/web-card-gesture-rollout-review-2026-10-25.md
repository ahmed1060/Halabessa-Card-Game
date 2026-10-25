# Web card gestures: pre-release verification

## Scope

The user approved enabling the previously reviewed swipe-up, swipe-down public
reveal and long-press slam in both online rooms and practice. This continuation
changes feature availability and packages the reviewed renderer; it does not
retune motion or modify domain rules, timers, scoring, bot logic or permissions.

- One shared policy permits offline practice and explicitly opted-in
  server-authoritative rooms, never legacy client-managed online rooms.
- Existing spectator and Unity visual-action/refined-hand capability gates stay.
- Hosting explicitly builds the three interaction/refinement/online flags true.
  Native build defaults stay unchanged. Independent online/all-gesture rollback
  controls remain available at compile time.
- The 24 October reviewed Unity WebGL files now replace the older shipping
  files. `unity-release.json` records payload/source fingerprints. One stable
  release token covers loader, data, framework and WASM URLs.
- The dedicated PR workflow compiles the actual production web entrypoint with
  release flags before merge. Hosting repeats the gesture and payload checks.

## Local verification

- Full Flutter suite with exact web release flags: **658 passed**.
- Full default-off/rollback Flutter suite: **655 passed, 3 skipped**.
- Edge/server adapters plus reveal/privacy/unchanged-gameplay tests: **229 passed**.
- Unity payload, valid WASM, startup/context-loss fallback and entrypoint cache
  checks: **9 passed** (15 when the six server reveal tests are included again).
- Complete Edge entrypoint Deno 2.5.4 typecheck passed. Scoped Flutter analysis:
  no errors/warnings; 11 existing style/deprecation informational notices remain.
- Actual production `lib/main.dart` web build succeeded in 140.8 seconds:
  `main.3d73287adf075f39.dart.js`,
  `flutter_bootstrap.4559c4d0f8b27ba9.js`.
- Isolated real-screen browser build succeeded in 140.2 seconds:
  `main.7795a312d050b088.dart.js`. It uses the same release flags and shipping
  Unity payloads, with the existing cloud-free practice entrypoint only.
- In-app browser: the Unity canvas was visible with nonzero size, rather than
  merely falling back to Flutter. Downward reveal changed 3 to 2; long-press
  slam changed its independent 3 to 2. Play continued across hands. No captured
  browser warnings/errors were reported in the focused check. Queued lift,
  cancellation and release-origin behavior have deterministic widget tests;
  the live timer makes a single still screenshot insufficient proof of timing.

Flutter's JavaScript build succeeded. Its separate optional WASM dry run reports
existing dart:html/plugin incompatibilities; this is not a claim that the app was
migrated to Flutter WASM. Unity's packaged WASM passed actual validation.

## Backend release before frontend activation

Saved active version 68 source in the ignored local build directory for rollback.
Compared every deployed module with the tested repository: game engine and
lifecycle match; differences are the approved gesture metadata/privacy cleanup
and previously merged immutable audio upload protection. No unrelated backend
feature, migration or credential change was included.

Released existing `halabessa-api` as **version 69**, ACTIVE, bundle digest
`a68ec0830f0980d72e46108485afd253eeef552fb4964fa1f21efb297e4e6448`.
Re-downloaded source matches all **37** expected files after line-ending
normalization. Existing `verify_jwt=false` is preserved because the function
itself still validates Firebase ID tokens; no authentication was weakened.
Unauthenticated snapshot and show-command requests both returned **401
unauthenticated**, with the existing permitted site origin.

The current Supabase changelog/docs were checked. The TLS 1.2 CBC retirement does
not require relaxing security or changing these modern browser/CLI clients.
Security advisors reported only the existing informational no-policy entries on
three private service-only tables. No policy/schema edit was made.

## Remaining release and evidence boundaries

This report records pre-merge evidence. Frontend publication requires fresh PR
checks, merge and successful Hosting deployment, then live asset verification.
An already-open game keeps its old JavaScript until reloaded after deployment.

No real online test account/room or physical phone was created/used by this
continuation. Online correctness/privacy use the real server command modules and
two-recipient parser/revision tests; that is not a measured two-human internet
latency test, physical vibration check or subjective audio timing certification.
Existing unrelated dirty platform/Gradle/analyzer files were preserved/excluded.

Modern Web Guidance's Emscripten guidance was inspected, but no new compiler
flags, threading model or browser API was adopted: the supported Unity loader
and existing Flutter fallback remain intact.
