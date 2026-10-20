# Local card-placement correction — 2026-10-19

User reported misplaced cards and supplied a portrait screenshot. This pass is
local-only: no commit, push, deployment, native export promotion, or live account
mutation. Active checkout: `build/lantern-remote-final`.

## Findings and surgical fixes

1. **Animation timeout discarded screen-space geometry.**
   `UnityVisualPresentation` used the animation-capability flag for both pacing
   and `SYNC_STATE.instant`. After a watchdog timeout it sent non-instant legacy
   snapshots; Unity then used its old world-unit positions/scales despite the
   Flutter HUD remaining in Option B coordinates. The negotiated layout is now
   retained separately, including size/anchor updates after a timeout. Animation
   acknowledgements and watchdogs still affect visuals only.
2. **Deal deck moved into the playfield with the dealer.** The deck now has a
   reserved Option B slot left of the top player, matching the approved mockup.
   The actual dealer badge, cut ownership, deck count and dealing rules are
   unchanged. `DealDeck` reuses the existing artwork/labels; `DealerSeat` remains
   compatible for other callers.
3. **Previous-round board leaked into cut/reveal presentation.** Native snapshots
   hide the old board during waiting/cut/reveal, while Flutter owns the existing
   cut-card reveal. Flutter also hides previous-round board artwork before cut.
   Authoritative board membership is not modified.
4. **Landscape table/hand collision.** Browser review caught the bottom of the
   table pile touching the hand. The board reservation moves up 28 logical units;
   Flutter and native table cards share a 64 x 92 size. The approved hand position
   and its input targets remain unchanged.

## File-touch map

- `lib/features/game/presentation/providers/unity_visual_presentation.dart`:
  retain layout negotiation on timeout; cut/reveal visual filtering.
- `lib/features/game/presentation/widgets/option_b_table.dart`: fixed deck slot,
  shared table-card size, landscape board reservation.
- `lib/features/game/presentation/widgets/dealer_seat.dart`: extract reusable
  deck artwork without changing existing callers' behavior.
- `lib/features/game/presentation/pages/game_board_screen.dart`: use the fixed
  deck slot and shared table-card size; pre-cut visual filtering.
- `lib/features/game/presentation/widgets/board_cards_widget.dart`: use the
  same table-card size as native anchor generation.
- `test/unity_visual_presentation_test.dart`, `test/option_b_table_test.dart`:
  timeout/resize regression, reveal privacy, four dealer placements, and
  landscape pile/hand clearance.

No new bridge message type or Unity script change. Existing version/order,
generation fences, cancellation, and snapshot fallback remain intact. No timing,
queue budget, haptic/audio hook, rule, score, deadline, or command change.

## Verification and local review

- Full Flutter suite after final adjustment: **515 passed**, saved in
  `build/card-placement-flutter-tests-2026-10-19.log`.
- Targeted layout/bridge tests: 16 passed. Geometry coverage includes 390x844,
  430x932, 844x390, 932x430 and 1280x720; actual widget input tests cover both
  portrait and landscape.
- Scoped Dart analysis: no errors/warnings; seven informational lints.
- Local release web build succeeded. The already-verified isolated Unity WebGL
  artifacts were restored into this QA output; no native rebuild is claimed.
- Actual hybrid browser view inspected at 430x932 and 932x430 and rotated back.
  Hand remains bottom-right, board is central, deck stays left of the top player.
  No warnings/errors attributed to the fresh `:9111` page were observed.
- Screenshots: `build/card-placement-portrait-2026-10-19.jpg` and
  `build/card-placement-landscape-2026-10-19.jpg`.

Review URL: **http://127.0.0.1:9111/?renderer=unity**.
Comparison: http://127.0.0.1:9111/?renderer=flutter.
Fresh port avoids the stale cached build previously served at `:9110`.

This verifies these identified placement defects, not every unspecified bug or
native-device behavior. Previous online/native qualification gates in the
2026-10-15 local-review report still apply. No phone/Mac testing is claimed.

Rollback remains presentation-only: compare with the Flutter renderer or disable
the existing card-juice build flag; no game data reset is needed.
