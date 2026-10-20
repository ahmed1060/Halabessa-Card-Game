# Approved A / D / E / F implementation — 2026-10-20

Active checkout: `build/lantern-remote-final`, branch
`codex/option-b-final-layout`. Local review only; no push or deployment.

## Approved appearance

- A: round-results velvet scoreboard. Navy woven surface, double brass frame,
  opponent coral / local mint, cumulative scores separated from round awards,
  paired statistics and the existing automatic countdown.
- D: cut message attached to the existing deal deck. The deck no longer moves
  to a separate cut position. On landscape the callout points upward beneath
  the deck to avoid covering the teammate; portrait uses a side pointer.
- E: shuffle status at that same deck. The existing instant shuffle is presented
  with a bounded 650 ms visual motion/message. The legal cut remains available
  during this cosmetic status; the UI does not extend the cut deadline, create
  a new phase, change shuffle votes, or wait for animation completion.
- F: final results use the same navy/brass team frames, actual scores and earned
  rewards, real portraits and translated names. Winner decoration follows the
  existing supplied `firstWon` value. Existing optional replay/rematch/home
  callbacks and pending/retry guards remain the only actions.

## Presentation-only file map

- New `lib/features/game/presentation/widgets/velvet_score_frame.dart`:
  code-painted frame and shared score tile. No baked-in numbers or names.
- Updated `round_summary_panel.dart`: layout only; still consumes
  `RoundScoreBreakdown`, harvest data and the existing round countdown/clock.
  Unknown awards are not invented; recorded available awards remain visible.
- Updated `match_result_view.dart`: responsive layout only; existing navigation
  callbacks, failure recovery and single-request guards retained.
- Updated `match_phase_panel.dart`, `dealer_seat.dart`, `option_b_table.dart`:
  shared deck location, attached prompt and cosmetic shuffle. Reduced motion
  skips the effect; old snapshots do not replay it.
- Updated `game_board_screen.dart`: connects presentation flags and localized
  shuffle labels; fixes result-only portrait/name rendering. Cut still uses the
  existing dealer check and `performCut(20)` callback.
- Three translation files gain shuffle-status copy only.

No game-domain, functions, Supabase, Unity source, protocol, timer, scoring,
ownership, bot or reward-write changes in this pass. Existing dirty work from
earlier passes was preserved. The project skills guided the presentation-only
boundary and central-playfield / mobile-layout review.

## Verification

- Full Flutter suite: **542 tests passed**.
  `build/approved-panels-full-tests.log`.
- Scoped analysis of the new/changed result and phase widgets: **no issues**.
  `build/approved-panels-analysis.log`.
- Eight deterministic production-widget renders: **8 passed**;
  portrait 430×932 and landscape 1004×430, for round, final, cut and shuffle.
  `build/design-review/approved-{round,final,cut,shuffle}-{430,1004}.png`.
  Fixture scores/rewards/players are test-only and are not inserted into a game.
- Rematch regression checks cover 667×375, 844×390 and 932×430. Short landscape
  uses a side-by-side results/decision composition so live vote choices remain
  visible; larger text retains scrolling instead of shrinking controls.
- Local release-web preview rebuilt successfully. All four local Unity Build
  files match the previously verified export by SHA256; Unity was not rebuilt
  because this pass changes Flutter presentation only.
- Live browser cut-to-play flow verified using the Unity renderer. No browser
  errors/warnings were returned in the checked session.

## Follow-up: wider local hand

The requested local-hand spacing increase uses a 15% wider fan region, yielding
approximately 23% more center-to-center card separation at the reviewed sizes.
`HandFanGeometry` preserves the original card width and height; both Flutter
hit targets and Unity anchors use that same geometry. Landscape retains the
central board exclusion region. Portrait shifts the expanded fan slightly left
to keep its right edge on-screen. Bot fans are unchanged.

Files: `fanned_hand_widget.dart`, `option_b_table.dart`, the visual-anchor call
in `game_board_screen.dart`, and the geometry check in `test/fanned_hand_test.dart`.
Follow-up full regression suite: **543 passed**
(`build/roomier-hand-full-tests.log`). No domain or Unity-source changes.

Local game: <http://127.0.0.1:9111/?renderer=unity#/game>.
The server is bound to 127.0.0.1 only. No production Unity embed promotion,
commit, push, new package, live-room mutation or physical-device certification.

The layouts implement the approved direction; they are not a claim of exact
pixel identity to AI-generated reference images. Brass ornament, fonts and
illustrations retain the implementation's available assets. Original mockup
artifacts remain in the chat's generated-image directory for comparison.
