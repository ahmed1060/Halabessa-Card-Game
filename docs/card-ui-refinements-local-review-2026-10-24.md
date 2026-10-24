# Approved card/UI refinements — local implementation review

Date: 24 October 2026. Checkout: `build/lantern-remote-final`, branch
`codex/card-interaction-startup-polish`, baseline `a032f765`.
User approved the annotated mockup and then selected sound A, dry paper edge.

## Implemented

- Capture history uses plain mint/coral numerals, without number discs.
- Bot nameplates contain only their names. Difficulty-only tips attach to the
  circular portrait and name; the local player's tooltip is suppressed.
- New opt-in `HALABESSA_CARD_UI_REFINEMENTS` defaults off. The existing hand and
  renderer paths remain available when it is disabled.
- `HandCardPlacement` projects the same owned IDs into private fan/public-right
  slots. Domain membership/order are untouched. The private/public boundary has
  a measured 8–16 logical-pixel visible gap inside the fixed four-card envelope.
  Physical right is not mirrored by Arabic text direction.
- A swipe-up queue retains a bounded released lift without the gold queue rim.
  Short-tap cancellation, replacement and the existing turn-entry cancellation
  window remain intact. Local flights retain actual release position and size.
- Public reveals use the same interactive owner card, not a duplicate above the
  hand. Up to three accepted public faces remain beside the owner fan; observer
  backs plus faces retain the original held count. Reveal never plays a card.
- Bottom-right amber hand/mint eye icons show accepted remaining uses; there are
  no Reveal/Slam text pills or per-card move badges. An active intent highlights
  its counter; keyboard focus retains a separate accessible cue.
- Refined gesture slam: 140 ms windup, 160 ms strike, 50 ms contact hold and
  150 ms settle. Larger near-camera lift and localized compression; no global
  time-scale change, page/HUD shake or rank-obscuring overlay.
- Approved sound A replaces the local slam fallback under the refinement flag.
  All three existing routing slots use the selected sound, not unapproved B.
  Its 44.1 kHz mono PCM bytes match the reviewed candidate (19,448 bytes,
  FNV-1a32 `3132475412`). It is procedural synthesis, not recorded Foley.
  Existing audio/haptic ownership, contact deduplication and preferences remain.
- Unity advertises optional `UNITY_CARD_UI_READY` version 1 support. Refined
  snapshots/poses are sent only after negotiation. Private pose caches contain
  local-owned IDs only and clear on scope/ownership changes. An opponent action
  preserves a valid local raised pose. Legacy exports retain the old schema/path.

## Verification

- Full Flutter suite with all three local flags enabled: **629 passed**.
  A subsequent parallel rerun after the gap adjustment recorded 628 passes and
  one failure in the untouched real-time retry-cancellation test (a request had
  not been scheduled within its fixed 35 ms wait). Its complete file then passed
  all 23 tests independently. The final bounded-concurrency whole-suite rerun
  passed **all 629 tests** in 2:33, recorded in
  `build/refined-final-full-tests.log`; no transport/test timing code was changed.
- Default/flag-disabled presentation, gestures, bridge and audio regressions:
  **111 passed** before the final shared-gap tightening, which only executes in
  the refined path. Legacy geometry and audio remain unchanged by that edit.
- Final visible-gap and all-seat reveal-layout run: **28 passed**, including
  portrait/landscape, up to three public cards per player and protected bounds.
- Existing isolated server validation tests: **6 passed**. These verify
  independent per-player reveal allowances, accepted-only slam consumption,
  disclosure privacy and unchanged gameplay outcomes. No live server was used.
- Scoped Flutter analysis: **0 errors, 0 warnings**; 21 informational existing/style
  notices remain. This is not a claim that the whole repository is lint-clean.
- Connected Unity temporary Play Mode harness: **13 checks passed**. It covers
  old cues/cancellation, stale selection, single contact, reduced motion,
  refined raised pose without rims, same-root public movement and stronger slam.
  Refined contact was observed at about **274 ms** in this Editor run; that is
  software event timing, not a physical speaker/vibration latency measurement.
- Verified incremental WebGL build `build_09af62cddf6d`: **0 errors, 1 warning**.
  The warning disables Pipeline automation in Player builds; it does not disable
  the game's Unity renderer. The earlier build's pending-compilation warning was
  resolved by compile verification and this subsequent build.
- Editor left stopped, compilation idle, `Assets/GameScene.unity` clean/unsaved.
- In-app browser exercised actual local Unity and Flutter views. A downward
  reveal and long-press slam changed their accepted-use counters. Native visual
  completion messages continued during multiple hands; there were no captured
  browser errors/warnings in the focused check. This is a smoke test, not a
  guarantee against every possible long-session/background/device failure.
- Presentation-source diff passes whitespace checking with tracked CRLF respected.

## Review artifacts and local entry points

Generated local-only output (ignored by Git):

- `build/card-ui-refinements-web/`: final Flutter QA build with the fresh native
  player copied ONLY into this generated output, not tracked `web/Build`.
- Final main bundle: `main.aa43dea6516f48be.dart.js`.
- `build/unity-ui-refinements-2026-10-24/`: verified isolated WebGL export.
- `build/design-review/tabletop-1004-play-reveals-refined.png`: real rendered
  widget fixture, not an AI mockup; all players have three public cards.
- `build/design-review/tabletop-430-play-reveals-refined.png`: portrait fixture.
  Existing width-only artifact names mean the shorter 430-wide viewport replaces
  the taller one during the same test run; both viewport assertions still run.
- `build/sound-review-2026-10-24/A-dry-paper-edge.wav`: approved review candidate.
- `tool/serve_card_ui_preview.dart`: GET/HEAD-only host bound to 127.0.0.1:9113.
  It does not deploy files or bind to an external interface.

Review URLs while the local host is running:

- Unity: `http://127.0.0.1:9113/play.html?renderer=unity&lang=en#/game`
- Flutter: `http://127.0.0.1:9113/play.html?renderer=flutter&lang=en#/game`
- Omit `lang=en` for Arabic.

Exact local flags:
`HALABESSA_CARD_UI_REFINEMENTS=true`, `HALABESSA_CARD_INTERACTIONS=true`,
`HALABESSA_DECK_SPICES=true`; trace is enabled only in this isolated QA build.
The QA entry point is `tool/option_b_preview.dart`, not production `lib/main.dart`.

## Protected boundaries and remaining gates

No edits to game engines/domain models, server authority/commands, timers,
scores, turn selection or voting. Uses remain three reveals AND three slams per
player across the complete 52-card cycle. Pre-existing dirty files were preserved.
No scene/prefab, workflow, production renderer export or native shipping binary
was replaced. No dependency update, account/room creation, push, merge, deployment,
store upload or live backend mutation was performed.

Still needed before calling this released/fully qualified:

1. User review of actual motion/feel on this local build. Automated timing tests
   and static fixtures do not establish subjective slam satisfaction.
2. Separate supported-online rollout qualification. The existing OFFLINE feature
   fence and default-off flags remain; the public website will not acquire these
   special gestures merely because the local QA build supports them.
3. Updated mobile binary/export qualification and physical Android/iPhone checks
   for gesture comfort, launch, haptics and sound latency. No phone/Mac was
   available; no claim of completed on-device validation is made.
4. Explicit publication approval remains separate from local acceptance.

Rollback: omit `HALABESSA_CARD_UI_REFINEMENTS` to restore legacy hand placement,
queue/rim profile, native metadata and slam fallback. Static tooltip/name/numeral
changes are independent presentation-only edits; do not roll back domain state.
