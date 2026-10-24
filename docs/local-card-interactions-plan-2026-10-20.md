# Local startup, card interaction and sound plan

Status: local implementation and automated verification completed subject to the
native/device gates below. On 21 October 2026 the user authorized checking Actions,
pushing, fixing CI and merging. The earlier local-only publication restriction
in historical checkpoints is superseded by that approval. Merge is gated on fresh
Android and iOS CI success; main's existing Hosting workflow then publishes normally.
No app-store upload or separate Supabase rollout is authorized.

## Native continuation — 22 October 2026

See `docs/native-qualification-2026-10-22.md` for the current native ledger.
PR #6 merged; all Android/iOS/Hosting merge-commit checks succeeded. Fresh
isolated Android and iOS Unity exports now succeed. Fresh-library ARM64 offline
QA and normal-entry APKs pass packaged launcher, signature, current protocol and
16 KB native/ZIP alignment checks. The Editor is restored to WebGL and its scene
is clean. This continuation remains local; committed native libraries are not
replaced. Physical Android/Mac/iPhone and final sound/feel review remain pending.
The older export/build limitations below are historical checkpoints.

## Latest closeout ledger — 21 October 2026

This ledger supersedes older checkpoint counts/pending-layout notes below; those
notes remain as historical evidence, not a claim that every gate is complete.

- Local implementation: approved card queue/slam/cancel and separate public
  show, three uses per player/full-deck cycle for each feature, hold feedback,
  fresh deal anchors, circular history counts, deck-side vote/cut/shuffle,
  startup handoff and compatible Unity ACK recovery are implemented. New
  interaction/deck features remain opt-in and online rollout stays fenced.
- Additional resume hardening touches only `unity_communication_service.dart`
  and `unity_game_view.dart`: cancel cosmetic queues immediately on focus loss,
  consume accepted hidden snapshots without requiring a frame, then reconcile
  with fresh anchors on resume. No missed theatrical history is replayed and
  later native actions remain enabled. Timers, rules, deadlines and networking
  authority are not paused or changed.
- Automated verification: **620 Flutter tests passed** with both preview flags;
  **618 passed** with default flags. **53 isolated Node tests passed** across
  feature validation/privacy, command delivery/fencing, native entrypoint
  contracts, web startup, landing routing and build fingerprinting. The new
  two-client fixture uses the real recipient parser and revision stream; twelve
  shows survive reordered/duplicate delivery, hidden hands stay recipient-only,
  and show/slam accounting remains independent. No live rooms/accounts are used.
- Layout: **35 opt-in reference/layout tests passed**, including actual game
  screens and twelve shown cards. Regenerated portrait/landscape references in
  `build/design-review/tabletop-*-*-reveals.png` include the circular mint/coral
  count badges. Reviewed 430-wide portrait and 760-wide landscape play frames:
  active cards, own hand, avatars, hidden fans and HUD remain unobstructed.
- Analysis of the four closeout source/test files: **no issues**. Broader legacy
  screen/style and fixture-localization warnings are not claimed fixed.
- Browser evidence: the rebuilt preview loads
  `main.afaea1e5f811c5a8.dart.js` via
  `flutter_bootstrap.9df744e1c86a69e9.js`. All four Unity files are copied from
  the verified `unity-focus-trace-qa` export, not the old web template export.
  User-assisted tab switching was followed by native play/slam contacts and
  typed completions; evidence is `build/design-review/unity-resume-trace.json`
  and `unity-resume-test.png`. This is a foreground/recovery sample, not a
  guarantee against OS/browser suspension or a complete performance profile.
- Normal web entry: a separate `lib/main.dart` release QA build at localhost
  port 9114 preserves landing -> Play -> `play.html` (no training parameters).
  A synthetic adult date was checked only in this local origin; the branded
  loading screen then reached normal sign-in, without signing in or creating an
  account. Evidence: `build/design-review/production-entry-local-signin.png`.
  Slow-asset and failed/disabled-Unity paths have deterministic tests; throttled
  physical mobile-browser testing is still a distinct qualification gate.
- Android toolchain: user separately approved wrapper 8.14.5 (official SHA-256
  pinned), AGP 8.11.1, Kotlin 2.2.20 and a checksum-verified official JDK 21 in
  ignored `build/local-android-tools`. Global Java settings are unchanged.
  A process-only documented Java socket temporary-directory
  option resolves the local loopback failure. The first compatible build passed
  version validation and installed its already-licensed NDK, then failed on
  Google Maven DNS resolution. A bounded official endpoint probe subsequently
  returned HTTP 200. The retry completed 156 tasks (151 executed), installed
  the already-licensed required SDK components, and then failed actual manifest
  merging: `flutter_plugin_android_lifecycle` requires minSdk 24 while the app
  declares 23. No override/bypass was used. The user subsequently explicitly
  approved raising the app minimum to API 24 / Android 7, dropping Android 6
  support. Only `android/app/build.gradle` changes for that decision; the Unity
  library's lower minimum does not need to change. The retry passed real Gradle
  manifest merging: minSdk 24, targetSdk 36, vibration permission and exactly one
  launcher (`com.halabessa.game.MainActivity`). The native-entrypoint regression
  tests also pass. The preview debug APK subsequently built successfully:
  374 tasks, 227 executed, 147 up-to-date. Android's own `aapt` decoded the
  packaged manifest and confirmed minSdk 24 / targetSdk 36, MainActivity and one
  LAUNCHER category. `apksigner` verified the v2 signature with one signer.
  ZIP inspection confirmed embedded ARM64 libunity, libil2cpp, libflutter and
  Flutter kernel. The APK is 208,924,324 bytes, SHA-256
  `f743bc56adc821f68ee20e7639896992e061e2c7a8770e19d7f63b36852a050e`.
  Preserved at
  `build/local-android-tools/artifacts/halabessa-card-feel-preview-api24-debug.apk`.
  This is the isolated offline QA entrypoint, not normal startup. A second
  `lib/main.dart` build initially failed in offline mode because the dynamic
  AndroidX runner version listing was not cached. Retrying with normal dependency
  access, without further source changes, succeeded in 2m33s (374 tasks, 18
  executed, 356 up-to-date). The normal-entry APK is 232,108,416 bytes, SHA-256
  `92b1841e5599f4e51a007abffb594e02b6ff90a72b8618901768b83856a537ec`,
  preserved at
  `build/local-android-tools/artifacts/halabessa-normal-entry-api24-debug.apk`.
  Its actual APK manifest also confirms API 24 / target 36 and one MainActivity
  launcher, its v2 signature verifies, and it embeds Flutter and Unity. Kernel
  inspection excludes the standalone `option_b_preview.dart` entrypoint.
  Neither artifact qualifies physical launch/vibration or new native card feel.
  The Unity payload is ARM64; other dependencies advertise additional ABIs, so
  cross-ABI native launch is a separate compatibility gate, not a build claim.
  Build-generated CMake output was preserved under ignored local QA tools;
  its tracked compilation database was restored to its pre-build contents and
  original EOF formatting. No runtime Unity export, scene or asset was replaced.
- Native packaging: source contracts and the actual cached Android manifest
  merger demonstrate one Flutter launcher versus two in the negative control.
  iOS source audit preserves Runner plus embedded UnityFramework. Neither is
  equivalent to installation/launch proof on a device. Read-only inspection
  also found that the checked-in Android Unity export lacks the rebuilt web
  player's new visual-protocol markers. A packaging build of that export cannot
  qualify new native card feel. The Editor is connected/ready, but the existing
  `BuildScripts.ExportAndroid` deletes the checked-in export directory; it was
  NOT invoked. A fresh isolated native export remains required before native
  animation qualification, without overwriting the old library or dirty scene.
- Remaining gates: fresh isolated Android Unity export and matching native-feel
  APK/ABI qualification (the packaging/startup review APKs above are verified);
  Android
  installation/one-icon/launch/haptic/audio latency checks; Mac/Xcode build and
  iPhone installation/launch/audio session checks; subjective recorded-Foley
  sample approval and final user visual/feel review. The user confirmed neither
  Android hardware nor Mac/iPhone is available. Procedural sound fallbacks are
  tested, but are not represented as licensed recorded Foley or phone testing.
- No commit, push, PR, merge, deployment, app-store upload, live account creation
  or backend/database write. Publication requires later explicit user approval.

## Approved: deck-side vote, cut and center-stage shuffle (21 October)

Status: APPROVED for local implementation, including the refinements, by the
user's “yes and approve the refinements also” on 21 October. Implementation and
verification are in progress. No publication is authorized by this approval.

### Baseline and intended result

The earlier D/E approval is recorded in
`docs/approved-panels-implementation-2026-10-20.md`: D attaches cut instructions
to the real deal deck; E attaches shuffle status to the same deck. The current
`shuffleVoting` branch still renders `MatchChoicePanel` in the central phase
region. `DealDeck` has only an in-place, 650 ms wiggle; a cut currently invokes
the existing `performCut(20)` without the proposed two-packet deck motion.

Move the marked deck-finished/shuffle-vote prompt into a compact, ivory/brass
deck-attached popover in the D/E family. Keep its real vote count, countdown,
both choices, pending guard and failure/retry state. The placement must adapt
to portrait/landscape without covering any avatar, capture history, or menu;
stack choices if necessary rather than shrinking their 48-logical-pixel targets.
This proposal does not move or restyle the separate rematch decision.

### Proposed visual beat sheet

- Cut, about 650 ms total: lift 80 ms -> separate two deck packets 140 ms ->
  carry the original upper packet around and underneath 220 ms -> align 130 ms
  -> weighted settle 80 ms. These are two stacks of intact cards, not a torn or
  sliced card. The packet split illustrates the existing cut position, not a
  new equal-halves rule. Remain at the real deal-deck anchor.
- Shuffle, about 1,200 ms total: travel from the real deck anchor to the actual
  table center and enlarge about 2x in 220 ms -> two restrained packet-mixing
  passes in 660 ms -> return home in 240 ms -> settle 80 ms. Use cubic travel,
  light velocity tilt, depth/shadow and spring-like settling. Faces stay hidden.
  Final scale remains responsive and must not cover scores or player controls.
- One visible presentation deck: hide its stationary artwork while the moving
  copy owns it; keep a stable anchor and real count. Remove the old wiggle only
  when the new presenter owns the effect, so no duplicate stack/animation runs.
- The vote/cut prompt belongs to the deck before/after the showcase. During the
  central shuffle, use only a compact status associated with the moving deck,
  not a second large decision panel. A valid Cut action remains available; if
  invoked during cosmetic shuffle, fast-finish/return that visual and perform
  the cut through the existing command, without extending its deadline.
- One Flutter sensory owner for paper separation, shuffle rustle and packet
  contact. Target impact requests 20-40 ms before contact; respect mute, volume,
  haptic preferences and focus. Existing domain sound calls remain intact but
  are suppressed while the matching presentation owns that event, avoiding
  double sound. Reduced motion uses a short local fade/settle, no center zoom.

### Protected authority and event contract

Clicking Shuffle continues to submit the current vote immediately. A small
button-press response may be immediate; the full shuffle plays only after the
accepted state confirms that shuffling actually occurs, including first-round
initial shuffle. A rejected/failed vote must never depict a completed shuffle.
Cut animation starts from the accepted existing cut transition. No optimistic
deck-order change, second cut command, or guessed card face is permitted.

Preserve deck order generation, cut index 20, dealer eligibility, voting rules,
deadlines, the existing cut-card reveal duration, deals, turns and scoring.
Presentation completion cannot advance the domain or networking. Bound the
cosmetic backlog to one current deck action, accelerate/skip if accepted states
overtake it, and settle to the latest snapshot rather than replay old motions.
Deduplicate by room/match/full-deck round/action/accepted revision or phase
identity. Cancel on room/renderer/navigation changes; reconnect, old snapshots
and resize must not replay a shuffle or sound. Recompute the home anchor after
orientation changes. Preserve the ordinary fallback path behind an opt-in flag.

The deal deck is already Flutter-owned in both renderers. Reuse that ownership
for these deck effects: no duplicate Unity deck, opponent-hand payload, new
native bridge command or Unity rebuild is planned for this addition.

### Exact proposed file-touch map (after approval only)

- New `lib/features/game/presentation/widgets/deck_action_presentation.dart`:
  bounded accepted-event presenter, two-packet cut and centered shuffle overlay.
- `lib/features/game/presentation/widgets/dealer_seat.dart`: expose/reuse real
  deck art and anchor; avoid the legacy wiggle while the presenter owns motion.
- `lib/features/game/presentation/widgets/option_b_table.dart`: deck-attached
  shuffle-vote layout, responsive exclusion zones and presentation overlay slot.
- `lib/features/game/presentation/widgets/match_choice_panel.dart` and
  `match_phase_panel.dart` in that directory: optional attached framing/status;
  retain current choice, request, retry and countdown behavior.
- `lib/features/game/presentation/pages/game_board_screen.dart`: connect the
  accepted deck transitions, shared anchor and prompt placement; keep the same
  cut/vote callbacks and avoid touching the rematch branch's behavior.
- `lib/features/game/presentation/providers/card_feedback.dart` and
  `lib/core/services/multimedia_service.dart`: scoped deck sensory ownership,
  preference gates and event deduplication, using existing cut/shuffle slots.
- `assets/translations/ar-EG.json`, `ar-SA.json`, `en-US.json`: only if short,
  deck-attached status text needs adjustment; retain the actual vote copy.
- New `test/deck_action_presentation_test.dart`; extend
  `test/match_phase_panel_test.dart`, `test/match_choice_panel_test.dart` and
  `test/approved_panels_visual_test.dart` for the proposed views and cancellation.
- Inspected but protected: game engine, deck ordering, game providers' cut/vote
  implementation, backend commands, Unity scripts/scenes and native packaging.

### Review, verification and approval gate

After approval, first present deterministic portrait/landscape frames for the
deck-side vote, split cut and enlarged central shuffle. Then verify the locally
animated sequence with both card renderers, large text, reduced motion, mute,
fast Cut during shuffle, failed votes, duplicate snapshots, reconnect and
rotation mid-flight. Replay the same accepted trace with presentation enabled
and disabled: identical card ownership/order, turns, scores and deadlines.
Run existing dealer/cut/shuffle-vote regressions unchanged. The new presenter
flag must restore the old visual path without changing an accepted action.
Keep all work local; publication still needs the user's later final approval.

Suggested refinements included for approval: brief packet separation shadow,
subtle card-edge flex at contact, two clean shuffle passes instead of a long
loop, a responsive pointer aimed at the deck, and no repeated text/toast spam.

### Local implementation / review evidence (21 October)

- Implemented behind `HALABESSA_DECK_SPICES` (default false). The local preview
  enables it alongside `HALABESSA_CARD_INTERACTIONS`; ordinary builds retain the
  legacy path. No dependency, bridge message, native export or domain/backend
  implementation was changed for this deck addition.
- One Flutter deck owns both renderers. Accepted cut: 650 ms, two intact packets
  (20/32), upper packet goes underneath. Accepted shuffle: 1,200 ms, center-stage
  2x travel/two mixing passes/return. Fast Cut replaces the remaining shuffle with
  a 120 ms return plus the cut, without delaying/submitting any game command.
- Vote uses existing choices, count, deadline, pending guard and retry. Portrait
  popovers now clear the existing menu; large text scrolls inside a clipped slot
  above the side avatars. During shuffle, full cut instructions become a compact
  live Cut control outside the central deck's footprint, then restore at home.
- Sensory ownership is separate from played-card contact audio. Existing domain
  cut/shuffle calls are suppressed only while this presenter owns them. Mixing
  cues have no haptic, contact has light haptic; preferences/focus/dedup apply.
  A fresh first-route shuffle catches up silently (its domain sound may already
  have played), while stale mounts do not replay. Confirmed rematches are fresh
  actions; old cut snapshots and room/renderer/resize/background changes settle.
- Verification: full Flutter baseline **595 passed**; full suite with both
  preview flags enabled **599 passed**. Subsequently added a real engine cut/deal
  on/off replay assertion; it passed with all **27** scoped deck/cut/shuffle/vote
  tests. Deck-specific analysis of eight files: **no issues**. Broader screen
  analysis still has existing informational lints/unused-avatar import.
- Actual game-screen portrait/landscape references: **6 passed**, including the
  vote's avatar/history/menu/score exclusion checks. Actual widget captures:
  `build/design-review/tabletop-430-vote.png`, `tabletop-1004-vote.png`,
  `approved-center-shuffle-430.png`, `approved-center-shuffle-1004.png`,
  `approved-split-cut-430.png`, `approved-split-cut-1004.png`.
- Local release preview rebuilt successfully; fingerprinted application
  `main.0817028ede8ccdd5.dart.js`, bootstrap
  `flutter_bootstrap.2018aeba8be96b0a.js`. All four copied Unity player artifacts
  match the previously verified QA export by SHA-256. No Unity rebuild was
  required. Browser review remains local at port 9113.
- Separate earlier qualification remains open: the opt-in twelve-public-reveal
  reference exposed a partner-avatar overlap in landscape; this deck request
  does not claim to fix that unrelated layout. No Android/iPhone hardware or
  Mac/Xcode is available for physical-device qualification. The real cached
  Android manifest merger did confirm one launcher with the app override versus
  two in the negative control; that is not a full APK/device test.
- No commit, push, PR, merge, deployment or live account/database write. Final
  user review and a later explicit publication approval remain required.

## Local progress checkpoint

### Continued verification and native focus follow-up (21 October)

Execution approval recovered. The focused recovery/gesture/layout suite passed
58 tests, and the full opt-in suite passed 612 tests. The handoff fixture needed
to acknowledge its test action before Flutter's pending-timer invariant check;
it now does. Analysis found no compilation errors, but existing screen warnings
and style lints remain. A rebuilt preview was actually loaded with fingerprint
`main.828329f7f4f4b141.dart.js`; all four Unity artifacts matched the previous QA
export. These checks do not prove the reported runtime defect fully fixed.

Live browser review exposed repeated ACK watchdog recoveries on ordinary moves.
Add a compile-time, default-off `HALABESSA_VISUAL_TRACE` in only
`unity_communication_service.dart` to log message types/generations/ACK shape,
not card, room or user identity. The diagnostic build confirms actions are sent
but no completion/contact signals arrive after native READY. Editor read-only
inspection shows `Application.runInBackground` and PlayerSettings background
execution false. Unity's official Web performance documentation confirms canvas
focus loss can suspend the update loop. Flutter owns the host input, and the
Unity canvas deliberately has pointer events disabled; this is a likely cause,
requiring a rebuilt native player/browser proof rather than a timeout extension.

Exact native plan: `UnityBridge.cs` sets `Application.runInBackground=true` only
under the existing `UNITY_WEBGL && !UNITY_EDITOR` Start guard. Keep keyboard
capture disabled, existing coroutine timings, privacy/ACK generations and native
mobile behavior. No scene, asset, PlayerSettings, package or rules edit. Build
an isolated local WebGL output with the connected Editor, without overwriting
the authored web shell or publishing. Restore any temporary build settings.
Verify fresh actions now return valid contact/completion ACKs after Flutter
interaction, and later deals remain aligned. Keep the bounded recoverable
watchdog for actual missing ACKs; never lengthen gameplay deadlines.

User additionally requests circular mint/coral count badges (16/21 screenshot).
Change only `TeamCapturePreview._count` in `option_b_table.dart`: fixed 24x24,
BoxShape.circle, centered existing digits/colors. Extend
`test/option_b_table_test.dart` to require equal dimensions and circle shape.
Keep count computation, click target, capture cards, text and location unchanged.
This remains local, unpushed, and not a claim of Android/iPhone haptic testing.

Follow-up results: final opt-in Flutter suite **617 passed**; the circle/handoff
fixture passed 12, and hold/fan/outline cancellation regressions passed 43.
New cancellation tests exposed recognizer disposal calling setState during a
locked layout when a card disappears or input is disabled. `_cancelPress` now
clears only private press/drag feedback synchronously and defers repaint during
persistent frame callbacks. No dispatch/queue deadlines changed. Reduced-motion
and background feedback checks pass. Seven-file final analysis has no errors or
warnings (four brace-style infos in the hand widget). Scene/ProjectSettings/
package status remains unchanged; scoped diff whitespace checks pass when CRLF
is treated as a line terminator, leaving unrelated pre-existing whitespace alone.

Native focus export **Succeeded**, zero errors, two existing warnings (runtime
Pipeline config absent and unused debug field), 15,629,342 bytes, 350.87 s. The
browser actually loaded Flutter `main.a6f9291e52ddcc1d.dart.js` and all four native
artifacts matched this new isolated export by SHA-256. Circular badges are
visible, with proof `build/design-review/circular-counts-local-browser.png`.
However, ACKs still time out while document.visibilityState is visible: the
focus change alone DOES NOT resolve the reported runtime failure. Do not claim
the Unity issue fixed. Keep bounded recovery, but further local diagnosis is
required. Native collection timing was inspected and is already separated from
legacy CardSlammed; no timing modification was made based on that hypothesis.

Further redacted QA plan: pass optional `trace:true` only under the existing
default-off local visual diagnostic define. `UnityBridge.cs` logs the incoming
action/cancellation generation, frame count and focus/background flags, and logs
when a contact/completion is actually emitted. Never log IDs, card payloads or
users. Native timings/commands stay unchanged; optional trace is ignored by older
players. A second isolated diagnostic export is in progress at
`build/unity-focus-trace-qa/web`; its completion and live trace still need review.

Native diagnostic export then succeeded with zero errors in 241.177 s. Browser
loaded Flutter `main.cd0d54c2baf39601.dart.js` and the diagnostic wasm/data matched
the isolated output hashes. Actual native logs confirm `focused=True` and
`background=True`, but only about 128 Unity frames elapsed over roughly 108 s
(frame 1 at 13:10:32Z; frame 128 at 13:12:20Z). The document reports visible/not
hidden. This is runtime evidence of sparse rendering, NOT proof the application
focus setting repaired it. A foreground-view check was requested asynchronously
from the user. Attempted cross-browser comparison could not run because Edge is
unavailable to the browser tools; do not claim a cross-browser result.

Final hold safeguard: backgrounding clears the unfinished press and prevents the
old recognizer from marking it after resume; a fresh tap starts normally. The
new release-after-resume test passes with all 18 gesture tests. Full opt-in suite
now **618 passed**. This remains distinct from actual phone haptic qualification.
Latest local web rebuild incorporating this safeguard is pending completion at
this checkpoint; restore the diagnostic QA player after that Flutter rebuild
(which otherwise copies the older web/Build artifacts), then fingerprint it.
Circular badges are implemented and tested; the Unity sparse-frame issue still
requires foreground/live qualification and must not be represented as resolved.

Final local refresh completed successfully (190.9 s); browser DOM confirms
`main.13c893bc6446957c.dart.js` and
`flutter_bootstrap.db7340423ded0bdc.js`. All four copied player files match
`build/unity-focus-trace-qa/web/Build` by SHA-256. Proof from the refreshed game:
`build/design-review/circular-counts-local-browser-final.png`. Both count badges
are true circles in the actual browser. No commit/push/PR/merge/deploy or live
account/database write occurred. The outstanding Unity sparse-frame diagnosis
is explicitly open, pending the requested foreground qualification; do not infer
completion from the 618 automated Flutter tests or the successful native export.

### Foreground qualification retry (21 October)

User replied “try again and will focus.” Kept the existing game/build, requested
the preview remain selected/foreground, clicked its existing Cut control and
observed at least 20 seconds without reloading or modifying source. Recorded
trace: **12 visual actions sent / 12 valid typed completions received**: one
CardDrawn, nine CardPlayed, two CardSlammed. Eleven contact signals correspond
to the eleven played/slammed actions; the deal has no contact cue. Generation
remained 5 throughout. No ACK-timeout log or runtime error/warning was returned
for this focused run. Native frame counters progressed normally (many frames
per action rather than approximately one frame per second). This is positive
live evidence that foreground motion and the native completion channel work;
the previous sparse-frame diagnosis was confounded by background throttling.
It does not qualify every long-session, background/resume or physical-device
case and does not erase the separate original missing-ACK regression repair.

Local evidence: `build/design-review/unity-foreground-trace.json` (redacted
types/generations/frame counts, no hand payloads) and
`build/design-review/unity-foreground-test.png`. Existing final fingerprint
`main.13c893bc6446957c.dart.js` was retained. No code change, rebuild, reset,
commit, push, deployment or external account/database write during this retry.

### Deal alignment and hold-build-up request (21 October; unverified source work)

User added the transient misplaced deal card and explicitly requested haptic
feedback/card tremble during a long press, stopping when marked. Source evidence:
`syncState` can dispatch a new four-card hand before GameBoard's post-frame
`_syncVisualAnchors` refreshes the per-card anchors. `updateAnchors` does not send
updates during an active native deal, so the final snapshot later corrects it.
This is a likely source of the observed temporary stack; runtime reproduction
and proof of the repair still require the local build/test gate below.

Plan / exact additional files: `unity_communication_service.dart` coalesces only
visual snapshots until the layout frame and its anchor callbacks are complete;
`unity_visual_presentation.dart` accepts anchor refresh without sending an old
snapshot during that pending handoff. Keep generation/privacy and all state
acceptance rules; no native protocol, game clock or Unity source change.
`fanned_hand_widget.dart` prepares a 180 ms delayed hold-build-up after tap-down,
then light pulses about 100 ms apart and a restrained 160 ms repeating tremble
until the existing long-press recognizer marks the card. Short taps remain on
their current path. Apply vibration to artwork only, retain fixed hit geometry,
and reuse `HAND_POSE` velocity for the native artwork. Stop on mark, up, cancel,
drag, card removal, interaction disable, background or disposal. Reduced motion
skips visual tremble; haptics still respect independent preference/focus gates.
`card_feedback.dart` owns haptic pulses (no extra sound), and
`game_board_screen.dart` supplies it. Add regressions to
`card_gesture_intents_test.dart`, `card_feedback_test.dart` and
`unity_visual_presentation_test.dart`; no domain/backend, scene or asset edits.
Add a focused `test/unity_visual_handoff_test.dart` service fixture to check the
post-frame/microtask ordering and cancelling a pending handoff on room leave.

Execution gate: the automatic escalation reviewer hit its account usage limit
before the recovery test/build could run. The rejection explicitly forbids
bypassing the approval check. Read-only inspection and permitted source edits
continue, but do not execute the rejected SDK commands through another path.
Latest browser still runs the previous verified build. Timeout recovery, the
new short-vote layout, deal alignment and hold feedback remain UNVERIFIED until
approved execution is available. Do not publish or claim the old 599-test result
as verification of these newer changes.

Prepared source and tests now include repeated hold pulses with a silent
preparation delay for short taps, Flutter artwork-only tremble and existing
native `HAND_POSE` velocity modulation; marking cancels both. The actual
misplaced-deal report has no validated runtime fix yet: the frame-coalesced
handoff and fresh-provider hand anchors are a source-level candidate repair.
Added missing-ACK and four-anchor regressions plus service handoff/leave tests;
they have NOT run after the approval-review rejection. Static diff inspection
also reports the communication file's pre-existing mixed CRLF whitespace;
formatter/analyzer remain pending alongside test/build. Do not treat the current
browser as running any of these source edits or change native packages/settings
to work around the gate.

### Unity effects disappear mid-game: local recovery follow-up (21 October)

The user's clarification is loss of Unity "spices" while gameplay continues,
not a stopped match. Preserved the current browser tab while inspecting it.
Confirmed source failure mode with a new RED regression: a single visual ACK
timeout set `_capable=false` permanently, with no automatic renegotiation from a
still-running Unity instance. This explains the reported symptom but no live ACK
trace was available to establish which particular action first triggered it.

Plan / exact files: `unity_visual_presentation.dart` retains the already
negotiated capability after the existing bounded timeout, cancels stale queued
motion, increments generation and sends latest same-space snapshot. Next fresh
accepted action can animate normally; never replay missed captures, audio, or
late ACKs. `unity_communication_service.dart` adds a local diagnostic on recovery,
without card/user data. `test/unity_visual_presentation_test.dart` verifies this
with missing/late ACKs, private cue preservation and later action completion.
No timing extension, domain/backend write, native message change, Unity rebuild,
or new dependency. Genuine load failure remains on existing 2D fallback path.

The user's screenshot separately exposed clipped vote choices on short portrait:
also update `option_b_table.dart` and `match_choice_panel.dart` to use a narrow
attached column between side seats when there is insufficient vertical space;
stack the original two controls instead of clipping them. Extend the existing
actual-screen reference checks to require both choices wholly inside the slot.
Verify unchanged deadline, pending/failure semantics, portrait/landscape, and
existing renderer/queue regressions. Keep all work local and preserve prior
layout fixes; no publication or game-rule change is authorized by these repairs.

### Maximum public-reveal layout follow-up (21 October)

Authorized by the user's local-work continuation after the deck review. Baseline
reproduced: the twelve-reveal game-screen fixture fails in landscape because the
partner's group is underneath its avatar/dealer badge. Portrait rail remains
unchanged. Planned change: relocate the partner's three copies into the open
right-side table column, one row above the right opponent's group with 8 logical
pixels between rows. Keep existing mint/coral ownership framing, public-copy
semantics, stable target gaps, 470 ms approach/flip/contact/settle, 180 ms catch-up,
contact audio ownership and reduced-motion behavior. No new bridge events or
Unity rebuild: the public-copy layer is already Flutter-owned for both renderers.

Exact files: `lib/features/game/presentation/widgets/shown_card_layer.dart`,
`test/shown_card_layer_test.dart`, `test/tabletop_reference_test.dart`, plus these
evidence notes. Inspect but preserve domain metadata/limits, commands, providers,
Unity scripts, hidden hands, active board and hand layout. Verify all twelve
copies against avatars, visible hand fans, scores/history/menu, board, own hand,
viewport and each other in portrait/landscape, including a narrower landscape.
Retain the existing `HALABESSA_CARD_INTERACTIONS` rollback flag. Physical-device
qualification and publication remain separate, unfulfilled gates.

Narrow-view evidence expanded the same presentation fix: at 760x430 the local
public copies touch the left bot's hand; lower only that group below the reserved
left seat when their rectangles intersect. At 430x740 the full Cut prompt crosses
the right avatar; also touch `option_b_table.dart` to bound attached prompt height
to the next seat, clip scrolling text, and reuse the existing compact Cut control
for short portrait layouts. No artwork, action timing or eligibility changes.

- Flutter-only offline prototype is available at
  `http://127.0.0.1:9113/play.html?renderer=flutter#/game`.
  Built from `tool/option_b_preview.dart` with
  `HALABESSA_CARD_INTERACTIONS=true`. The screen additionally fences new
  interactions to offline rooms. Unity additionally requires the optional
  `UNITY_CARD_FEEL_READY` handshake from the rebuilt export. Production and old
  Unity exports do not enable the new gestures.
- Tap/upward play, private queue/cancellation, hold/release slam, separate
  downward reveal, double-rim slam cue and contextual allowances are connected.
  A normal queued card can be upgraded by holding it; a short tap cancels it.
- Accepted shown copies use a bounded visual queue, owner approach or peer flip,
  contact hold and settle. Reconnect mounts silently; a real play removes only
  its matching shown copy. All twelve copies fit separately from the live board
  and hand in tested portrait/landscape geometries. Seat/HUD clearance, large
  text, tiny-screen readability and final art direction still need review.
- Browser smoke check confirmed a disclosed king remained in the owner's hand.
  This was one offline browser, not a real cross-client networking test.
- Isolated backend command tests cover actor/ownership validation, independent
  three-use counters across three hands, rejection/duplicate safety and identical
  normal/slam legal-play outcomes. No server or database was deployed/changed.
  Disclosed faces are omitted from lobby/public-match mirrors and retained in
  authenticated participant views. Account-deletion cleanup removes owner feature
  records without touching another player's reveal or gameplay fields.
- New cached procedural pick/return/reveal/slam sounds and bounded presentation
  voices exist. These are fallback samples, not recorded cardstock-edge Foley;
  subjective sound tuning and device latency remain unqualified.
  Six new slots are exposed in the existing admin SFX list, with English and
  both Arabic locale labels. No overrides were uploaded or changed remotely.
- App entry now gives its existing branded loading screen one second after its
  first frame, while still waiting for genuine assets/deletion/auth resolution.
  This is not invented progress, a Unity handshake or a new gameplay wait.
- Android source override removes the exported Unity activity's launcher filters
  while preserving the embedded activity. Source tests pass; no merged APK is
  certified yet. Java's loopback error was resolved with a short workspace temp
  path. The manifest build then reached a pre-existing toolchain mismatch:
  available Gradle 8.13 is below this Flutter SDK's required 8.14 minimum. No
  wrapper/toolchain files were upgraded or dependency checks bypassed.
- iOS Runner launch/framework source checks pass; no Mac/iPhone runtime check.
- Unity connection is restored in the correct checkout. Pipeline 0.8.0-exp.1
  was already installed; no package update was needed. The initial CLI catalog
  did not prove the main thread was usable; subsequent live evaluations did.
- `CardJuiceController.cs` and `UnityBridge.cs` now support private queued
  elevation/single or double amber rims and an optional gesture-slam delivery
  profile. Ordinary legacy capture meaning is preserved. Flutter owns input,
  sound/haptics and public-show copies; Unity owns its hand/board art and slam.
  The new bridge messages are generation-fenced, local-hand-only and deduplicated.
  Selection survives ordinary snapshots; cancellation clears it. Old exports
  retain their existing protocol-1 snapshot/action behavior.
- Live Unity compilation passed without errors. The explicit, non-shipping
  `tool/UnityCardFeelQa.cs` Play Mode fixture passed eight checks: persistent
  hover-independent double rim, unchanged collider count, stale-generation
  rejection, cancellation, bounded slam motion/contact and reduced motion.
  Measured contact was 276.8 ms and sequence completion 498.4 ms in that Editor
  run (frame-rate dependent, not a device-latency guarantee). Background updates
  were enabled temporarily for QA and restored. GameScene was opened through
  the Editor; no scene or project-settings file was saved or hand-edited.
  The harness then passed twice consecutively with current-generation allocation;
  contact measured 271.4/277.2 ms, completion 490.5/480.6 ms. Editor was left
  open and stopped afterward; no temporary scene state was saved.
- Isolated Unity WebGL export succeeded under
  `build/unity-card-interactions-qa/web`: 15,617,034 bytes, zero errors, 920.9 s.
  Warnings: Pipeline runtime automation is disabled (no runtime config, expected)
  and an existing unused UnityDebugConsole field. Editor automation remains
  available; no automation server is added to the player. The game host keeps
  its Flutter HTML/entrypoint; only generated Build player files are copied.
  All four preview player files were SHA-256 compared with this export and
  matched. Browser smoke check initialized Unity 6000.0.69f1/WebGL 2, dealt native
  hand/board art and accepted card input with no warning/error logs observed.
  This is not a full gesture, multiplayer, slow-network or device certification.
  Unity preview: `http://127.0.0.1:9113/play.html?renderer=unity#/game`.
- Final bridge review also replays a valid private selection immediately after
  a native visual action resets transient poses. An opponent's flight therefore
  cannot erase the local queued-card cue; it sends no gameplay/network intent.

Remaining gates: full Unity browser gesture qualification; production-entry web startup
reproduction; complete SFX coverage/tuning; isolated two-client ordering/privacy
checks; twelve-card visual review; merged native packaging and physical-device
qualification. The current prototype is NOT the finished cross-platform result.

Validation at this checkpoint: final full Flutter suite passed all 573 tests;
the focused bridge/audio run passed all 12 tests. The prior 40/40 focused Node
backend/delivery/deletion/native-source tests pass, changed backend adapters pass
TypeScript checking, and the scoped Flutter analysis has no errors (existing
game-screen warning/info diagnostics remain). `git diff --check` passes.
Logs are under `build/local-card-interactions-tests.log`,
`build/local-card-backend-tests.log`, `build/local-card-interactions-analysis.log`
and `build/local-native-manifest-short-temp.log`. No APK/device verdict is
implied by these source and unit-test results.

## Agreed direction

- No routine visible Next turn, Slam next turn or Cancelled labels. Use stable
  card elevation, an outline and a distinct non-text slam cue instead. Keep
  accessibility semantics; show genuine failures only when actionable.
- Preselection and its normal/slam style are private to the selecting player.
  No other client receives the queued card identity.
- Tap/swipe up retains normal play or preselection. Long-press selects slam
  delivery: release plays on the player's turn or queues that delivery off-turn.
  A short tap on a queued card cancels it and clears automatic submission.
  Cancellation is possible before submission, not an undo of an accepted move.
- Swipe down is a separate, intentional public show, not a play. The card stays
  owned by the player, remains playable, and changes no hand count, board card,
  turn, capture, score, deadline or winner. Its shown copy is not a capture target.
- The owner sees lift/approach and a slap beside the table cards; other players
  see a back approach, flip and slap. Reserve a visible gap and seat association.
- Keep up to THREE still-owned revealed cards displayed per player. The user
  explicitly rejected the proposed one-card display limit. A later reveal must
  not replace an earlier still-owned displayed card. Remove only the matching
  shown copy when its actual card is played; hand/round/departure cleanup still
  applies. Revealed artwork is a presentation copy, not another logical card.
- Add missing SFX and audit existing audible event coverage on both renderers.
- Check Android and iOS launch, packaging and Unity handoff, not only web.
- Each player has three public-show uses and a separate three gesture-slam uses
  across the entire 52-card deck cycle. The user confirmed these allowances are
  per player, not shared room-wide and not reset for each of its three hands.
- The user approved a small remaining-use indicator shown only while preparing
  the corresponding reveal/slam gesture, not as a permanent HUD panel.
- Keep the public introduction/SEO page for the main search result. Play opens
  the normal game entry directly, skipping that page; do not force training.
  Google choosing to show a separate Play sitelink is not guaranteed.

## Evidence and limits

Active checkout: `D:/Projects/Halabessa-Card-Game/build/lantern-remote-final`.
Preserve the pre-existing dirty analysis options and generated/native files.

1. `android/settings.gradle:30` includes
   `androidBuild/unityExport/unityLibrary`, not the similarly named
   `android/unityLibrary` folder. Its manifest declares a MAIN/LAUNCHER
   `UnityPlayerActivity` with `UnityThemeSelector.Translucent`, alongside
   Flutter's MAIN/LAUNCHER `MainActivity`. This is strong source evidence for the
   reported duplicate icons; inspect the merged manifest/APK to confirm.
2. `auth_wrapper.dart` ends initial loading after image warming/deletion checks
   and auth resolution. Unity is separately mounted on room entry and waits for
   UNITY_READY. A quick splash is not proof of a missing renderer. Reproduce
   cold/warm startup and record readiness/failure signals before fixing it.
3. `fanned_hand_widget.dart` already stores a queued card and dispatches after
   300 ms on turn entry. Its selected outline is inside artwork hidden for Unity.
   HAND_POSE transmits peek/drag/velocity, not a durable queued/slam designation.
   Current drag completion recognizes upward movement only; no long-press play
   or public-show command exists in the inspected paths.
4. The iOS Runner scheme runs Runner.app; Runner embeds UnityFramework. The
   packaging workflow copies Runner.app alone to Payload. The Unity export also
   contains a standalone app target, but its existence does not mean it is
   installed. No equivalent duplicate-icon cause is confirmed. No Mac/iPhone
   runtime test was performed on this Windows machine.
5. Eight procedural sound defaults exist: play, deal, capture, shuffle, cut,
   win, lose, purchase. Pick/reject currently provide haptics only. Capture is a
   chime, not the requested cardstock edge snap. Shuffle/cut/deal have local
   domain callers; trace shared online transitions for equal audible coverage.
   A single Flutter SFX player may truncate closely spaced effects: measure it
   before introducing a bounded voice pool. Do not assume a clip/hook is audible.

## Protected boundary and the public-show exception

Existing play/cut/capture/scoring/turn/deadline/bot/vote rules and server move
validation stay unchanged. Normal and gesture-selected slam use the same legal
play command; a forceful animation must not imply a successful capture.

The explicitly requested public-show feature does require a new validated shared
information action. Implement it as isolated presentation metadata, not by
putting an unplayed card into MatchState.board or making private hands public.
Verify authenticated membership and ownership against the current private hand;
accept only the caller's chosen card, never arbitrary client card faces. Permit
intentional show during active play even off-turn. Use existing transaction,
revision and command identity infrastructure; do not weaken database policies.
Remove stale display metadata on actual play, hand/round change or departure,
without changing those existing domain operations. A reveal cannot erase what
other players have already learned even if its visual is later removed.

### Feature allowances

Use the existing full-round/deck-cycle identity, scoped by room ID,
matchSequence and roundCount. handInRound advances through the three hands and
must NOT reset feature allowances. Reset at the next accepted full-deck round,
not on reconnect, renderer switch, device restart or account UI navigation.

Approved per-player allowances: three accepted public shows and three accepted
gesture-slams, counted separately. Queuing,
cancelling, hovering, rejected requests and duplicate deliveries consume zero.
A queued slam consumes one use only when the associated legal play is accepted.
Automatic capture/win impact effects are not player-selected slams and do not
consume this allowance. A public-show landing slap uses the show allowance only,
not both allowances. The UI should not arm an exhausted feature; normal legal
card play remains available. Validate and record allowances on the server in the
same idempotent acceptance path, with local equivalents for offline fixtures.
Do not trust client counters or loosen existing command/security checks.

Approved feedback: a tiny remaining-use cue only while preparing the limited
gesture, and a restrained unavailable response at zero. No permanent counter
panel and no routine queued/cancelled text. At zero, give a restrained visual
response and soft haptic, with NO implicit fallback that plays the card normally.
An ordinary, separately requested tap-to-play remains available.

### Approved interaction refinements

1. One pointer gesture resolves to exactly one action. Long-press release cannot
   produce a normal tap too. Use direction, movement thresholds and cancellation
   to arbitrate tap, upward play, downward show and hold-to-slam.
2. Public show and private preselection are independent: show neither queues the
   card nor cancels an existing queued selection or its chosen delivery style.
3. Exhausted reveal/slam gestures must never unexpectedly play a card normally.
4. Up to three displayed reveals per player are clearly separated from the
   active board with a visible gap, seat association and distinct hit testing.
   Across four players, test the worst-case twelve displayed reveals in portrait
   and landscape. Do not replace/hide an earlier reveal to meet a one-card cap.
5. Once a reveal is accepted and disclosed, visual cancellation/failure does not
   erase the disclosure or refund a use. Reconnect restores valid disclosed
   cards silently rather than replaying the reveal animation/SFX.
6. Gesture-slam sound/weight is distinct from genuine capture or scoring
   celebration. A dramatic gesture alone never triggers capture rewards/VFX.
7. Queue outlines, hold feedback and remaining-use cues are local-player-only;
   other clients receive only accepted public reveals and legal played outcomes.
   Use restrained sound and avoid repetitive hover feedback.

Also approved: small variation between a few card-slap sounds, with consistent
perceived loudness, mute/preferences and event deduplication. Do not overlap
multiple versions for one contact or use unlicensed recordings.

## Presentation beat sheet (initial proposals)

| Action | Proposed beats | Feedback / completion |
| --- | --- | --- |
| Queue / cancel | 100-160 ms lift or lower | Private persistent outline; immediate light haptic; no text toast |
| Long-press | About 450 ms hold | Continuous hold cue; movement threshold prevents accidental activation; no duplicate tap on release |
| Normal play | Existing validated dispatch, cubic flight | Keep legal input responsive; finish on visual settle |
| Public show | 100 ms approach, 180-220 ms flight/flip, 40-50 ms contact hold, 120 ms settle | A separate show-card anchor, paper snap and appropriate haptic |
| Gesture slam | 100 ms visual windup, 180-220 ms cubic flight, 50 ms impact hold, 120 ms settle | Stronger paper snap; optional 120 ms table-only shake, no capture celebration |
| Invalid/rejected intent | About 250 ms EaseOutBack return | Soft error sound/haptic, no public face disclosure |

Flutter and Unity share the same intended beats. A single existing Flutter-owned
visual queue drives them; Unity never becomes a second game authority. Target
audio/haptic scheduling 20-40 ms before predicted contact, with actual device
latency measured rather than promised. Never pause global game time/networking.
Reduced motion removes shake/approach/rotation and preserves a brief ordered
crossfade/readable result. Preserve real deadlines; bound added cosmetic backlog
to roughly 800 ms before shortening/skipping optional beats and resyncing.

## Bridge and multiplayer contract

- Extend the negotiated visual capability contract compatibly. Old builds keep
  their existing snapshots and fallback path; no new dependency is required.
- Keep queue selection/style local (Flutter to its own Unity view only).
- Public-show messages carry event ID, owner seat, room/match/round/hand scope,
  revision, selected validated card ID, style and timing. Serialize structured
  JSON. Do not send the rest of a private hand to renderers or other clients.
- Deduplicate events/audio and reject stale generations. A visual completion
  acknowledgement releases presentation only, never advances a turn or a move.
- Keep reveal metadata in the shared snapshot for reconnect, but do not replay
  old reveal animations or sound. For reveal racing a play, the actual accepted
  play wins and the displayed copy reconciles without duplicating cards.
- Retry ambiguous requests with their original ID; a failed reveal never blocks
  a legal play. Cancel local queues on room/hand changes, leave and disposal.
- Start with a local fake peer/server fixture. Real cross-client validation uses
  an isolated local backend/emulator, never the production room or database.

## File-touch map for implementation

All paths below are relative to the active checkout. This is a proposed map,
not permission to rewrite all listed files.

### Startup and native packaging

- `android/app/src/main/AndroidManifest.xml`: surgically override/remove only
  Unity's launcher filter in the merged app while retaining embedded integration.
- `unity/Halabessa/Assets/Editor/BuildScripts.cs`: export-time protection against
  reintroducing a standalone launcher; generated export changes only if needed.
- `lib/features/auth/presentation/pages/auth_wrapper.dart`,
  `lib/core/widgets/loading_screen.dart`,
  `lib/features/game/presentation/providers/unity_startup_state.dart`,
  `lib/features/game/presentation/providers/unity_communication_service.dart`,
  `lib/features/game/presentation/widgets/unity_persistent_overlay.dart`: only
  measured startup readiness/failure and single-surface handoff changes.
- Inspect `ios/Runner/Info.plist`, Runner.xcscheme, Runner project/workspace,
  `ios/Podfile` and iOS build packaging; edit only a demonstrated fault. Add local
  artifact checks for one top-level app and embedded UnityFramework.
- Keep `web/landing.html` as the introduction/SEO root. Its existing Play anchors
  already point to `play.html`, whose production build uses normal lib/main.dart.
  Practice remains an explicit choice in the game, not the Play destination.
  Only edit these links if a reproduced local routing fault requires it. Actual
  startup fixes may touch `web/index.html` and `web/flutter_bootstrap.js` after
  web-guidance review. Preserve readable bilingual SEO, canonical URL,
  verification file, sitemap, legal pages and legacy routes. Do not add cloaking,
  Google-referrer-only routing or forced training parameters. play.html currently
  has noindex, so do not promise it can appear as a Google sitelink; changing its
  search-index policy would be a separate SEO decision, not a loading fix.

### Gesture, rendering and public-show metadata

- `lib/features/game/presentation/widgets/fanned_hand_widget.dart`:
  private queue/style state, long-press arbitration and downward-show gesture.
- `lib/features/game/presentation/pages/game_board_screen.dart` and
  `lib/features/game/presentation/widgets/option_b_table.dart`: bind show/queue
  visuals, separate anchors and preserve the approved central playfield layout.
- `lib/features/game/presentation/widgets/local_card_play_layer.dart`,
  `lib/features/game/presentation/providers/unity_visual_presentation.dart`,
  `lib/features/game/presentation/providers/unity_communication_service.dart`:
  optional style metadata and one renderer owner, reconciled accepted events.
- New `lib/features/game/presentation/providers/card_reveal_controller.dart`
  and `lib/features/game/presentation/widgets/shown_card_layer.dart`: isolate
  public-show state/presentation from actual board card ownership.
- `unity/Halabessa/Assets/Scripts/UnityBridge.cs` and `CardJuiceController.cs`:
  explicit selection styling and show/slam/flip profiles with compatibility.
- New `supabase/functions/halabessa-api/card_reveal.ts`; small extensions to
  `match_commands.ts`, `match_delivery.ts`, and the public projection/adapter if
  required. `lib/features/game/domain/models/match_state.dart`,
  `lib/features/game/data/repositories/multiplayer_sync_service.dart` and
  `lib/features/game/domain/providers/game_providers.dart` may need narrow
  optional-metadata/command plumbing ONLY. No engine or lifecycle rule changes.
- `assets/translations/ar-EG.json`, `ar-SA.json` and `en-US.json`:
  accessible queue/show descriptions and actionable errors, not routine labels.

### Sound coverage

- `lib/features/game/presentation/providers/card_feedback.dart`,
  `lib/core/services/multimedia_service.dart`,
  `lib/core/services/default_audio_assets.dart`: event-specific sound profiles,
  ownership, preference gates, local fallback and bounded playback concurrency.
- `lib/features/home/presentation/pages/admin_sfx_management_screen.dart` only
  to expose new sound slots consistently with existing overrides, not new menus.
- Add real, owned/licensed local Foley assets only after approval of samples;
  preserve procedural fallbacks and do not depend on a remote sound URL.
- Existing Unity AudioManager remains a legacy path to inspect; do not make it
  play duplicate effects alongside the Flutter sensory owner.

## Work order and verification

1. Local Android launcher regression check; iOS source/package audit. Reproduce
   startup on cold cache, warm cache, slow connection, disabled 3D and failed Unity.
2. Gesture prototype with explicit private visual states and cancellation;
   demonstrate normal queued play versus queued slam without visible text labels.
3. Public-show local two-client fixture, then validated isolated backend plumbing.
   Confirm other hands remain private, shown cards never enter board counts or
   captures, real plays remove the shown copy, and reconnect is silent/idempotent.
   Add allowance tests for the first/third/fourth attempt, cancellation, retries,
   duplicate accepted snapshots, all three hands, next full-deck round, player
   identity, reconnect, and independent show-versus-slam accounting. Assert that
   one player's use never decreases another player's remaining allowance.
   Test three simultaneous shown cards per player, twelve room-wide, play of a
   shown card removing only its own copy, reveal preserving queued choice, and
   zero allowance producing no play command. Verify long-press releases once.
4. Tune Flutter motion/audio first, then equivalent Unity profiles. Validate all
   pointer paths, keyboard equivalent, portrait/landscape, mute and reduced motion.
5. Extend `test/fanned_hand_test.dart`, `hand_outline_alignment_test.dart`,
   `card_feedback_test.dart`, `unity_visual_presentation_test.dart`,
   `unity_startup_test.dart`, `local_card_play_layer_test.dart`,
   `startup_assets_test.dart` and `lantern_loading_test.dart`. Add dedicated
   reveal and native packaging tests; extend backend command/privacy tests.
6. Replay accepted gameplay traces before/after: identical cards, turns, scores,
   deadlines and winners (only explicitly requested reveal, delivery-style and
   feature-allowance metadata differs).
7. Review local browser recordings and Android APK together. iOS launch,
   transparency, audio-session and device feel remain unverified until a Mac
   build and iPhone test are available; do not trigger remote CI as a workaround
   for the user's local-only approval gate.

Use a development-only opt-in toggle for new gesture/juice presentation, and a
separate capability gate for public show. Rollback cancels effects/queues and
reconciles to the latest permitted snapshot; it cannot un-disclose a shown card.
No push, PR, merge, production backend deployment or Hosting publication until
the user reviews the finished local result and explicitly approves.

## Approved enhancements and remaining layout qualification

- Normal queue: one steady rim; queued slam: distinct double rim/corner accent.
  Neither selection nor queued identity is shown to opponents.
- Avoid gesture collisions: a downward threshold/velocity and horizontal escape
  zone distinguish intentional show from long-press and normal drag.
- Keep up to three currently shown cards per player, as explicitly requested.
  Use responsive, seat-associated groups beside the active table cards, with a
  clear gap. Review the twelve-card worst-case locally before final placement;
  keep active ranks, hand gestures, HUD and queued selection unobstructed.
- Private preselection should survive reordering, but never a new hand/room.
- Add subtle turn-start and ready feedback, no repetitive hover/clock spam.
- Web flow is clarified: introduction on the main result, normal game via Play,
  and no automatic training. A Google Play sitelink cannot be promised and is not
  configured by adding a button to the homepage.
- Approved: three show uses and three gesture-slam uses per player per full
  52-card cycle, with the small contextual remaining-use indicator. Keep this a
  new scoped feature limit, not a rewrite of the finished
  card/deck/capture/scoring/turn rules.
