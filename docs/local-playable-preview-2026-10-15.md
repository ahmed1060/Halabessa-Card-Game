# Local playable review — 2026-10-15

## Review gate

User requested the final result locally before any push. No commit, push,
deployment, player/account mutation, or copy into native embedding paths is
authorized by this preview. Active checkout remains `build/lantern-remote-final`,
branch `codex/option-b-final-layout`.

Local URL: `http://127.0.0.1:9110/?renderer=unity` (Arabic default).
Compare Flutter rendering: `http://127.0.0.1:9110/?renderer=flutter`.
Append `&lang=en` for English. Reload starts an isolated local practice match;
the dealer's existing Cut control starts the round. No cloud services/accounts.
Leaving a match goes to a local restart hub with a renderer selector.

## Surgical plan and implemented scope

1. `CardJuiceController.cs`, `UnityBridge.cs`: managed local-hand tap/drag
   requests use the existing validated Flutter intent path; no table/opponent
   input, duplicate pending requests, or fabricated legality. Invalid drops
   spring home in 250 ms. Legacy DragMe sources/configuration remain untouched.
2. `game_board_screen.dart`, `unity_visual_presentation.dart`: optional normalized
   card sizes and individual hand centers align native art with the existing
   Option B hit targets. Center-only snapshots remain supported. Dense native
   cards use restrained scatter rather than .006-world-unit offsets.
3. `fanned_hand_widget.dart`, `unity_communication_service.dart`,
   `unity_persistent_overlay.dart`: Flutter owns the actual full-HUD hand
   controls, keyboard semantics, queue selection and request guard; Unity
   receives generation-fenced cosmetic HAND_POSE cues. Native rendering does
   not independently process another copy of those Flutter gestures.
4. Shared `game_table_background.dart` preserves selected cafe assets beneath
   the retained Unity view. The view paints while loading so its platform canvas
   can attach; the fallback remains authoritative for visibility until READY.
5. `lantern_page_transitions.dart`: only `/game` has a transparent transition
   backdrop, so it does not permanently obscure the retained renderer. The
   app-root cafe fill and other page-transition backgrounds remain opaque.
   A trial CSS canvas-background workaround was removed after the actual
   occluding transition backdrop was identified; web registry files are unchanged.
6. `tool/option_b_preview.dart`: real offline practice controller, approved
   ThemeConfig, retained renderer and local audio hooks. No new bot/rule engine.

Timings remain the approved pacing: ordinary visual action 350 ms (native flight
220 ms), capture read/collection budget 1400 ms, 50 ms slam pause, 120 ms subtle
shake, 30 ms contact lead, 250 ms invalid return. Reduced motion bypasses dramatic
motion. Visual acknowledgements never advance domain turns or scores.

## Verification

- Final full Flutter suite: **514 passed**, after startup and route fixes.
  Saved output: `build/local-playable-preview-flutter-tests.log`.
- Targeted startup/input/bridge follow-up: 31 passed; route/startup checks: 5 passed.
- Real-frame Unity Editor fixture: 49 checks passed, including physical root
  drag movement, one pending intent, table exclusion, rejected return, legacy
  center-only anchors and normalized-size anchors. Report:
  `build/unity-card-art-deferred-smoke.json`.
- Refreshed isolated WebGL export: succeeded, 0 errors, 2 warnings,
  15,643,034 bytes. Warnings are disabled-in-player Pipeline and the existing
  unused debug-console field. Report: `build/unity-card-juice-web-build-report.json`.
- Actual full-HUD browser startup revealed and fixed both hidden-platform-view
  attachment deadlock and an opaque page-transition backdrop. This was not
  discovered by pretending fixture-only screenshots qualified the full game.
- Actual hybrid portrait physical card tap: Seven of Spades moved from the
  local hand to the table, hand count changed from 2 to 1. Native hand controls
  measured 79.425 x 113.575 CSS pixels in the 430x932 run.
- Native card sizes and table artwork inspected at 430x932 and 932x430.
  Physical score swipe-up collapsed the HUD; swipe-down restored it, with no
  playfield reflow. No error/warning entries observed in the tested browser run.
- Host origin/source/method/buffer test and WebGL alpha-clear boundary test pass.
- Scoped analysis has 0 errors/warnings, with 6 informational legacy lints in
  GameBoardScreen. Protected rule/backend/prefab/settings diff remains empty.

## Before native promotion

This is a local visual review, not an online/native store release qualification.
Do not claim physical Android/iPhone haptics, audio latency, lifecycle behavior,
Xcode compilation/signing, or new mobile exports from this browser run. No phone
or Mac/Xcode is available. Prior Android/iOS QA exports predate this input pass.

Flutter-only online optimism is unchanged. The native renderer uses its accepted
visual queue (with immediate pick/peek feedback) rather than a duplicate Flutter
optimistic ghost. Native online prediction/reconciliation and real network/device
latency still require dedicated qualification before native promotion. Dense
native pile count/disclosure parity and native round-win particle references also
remain review items; Flutter's existing win celebration remains in place.

Rollback: rebuild with `HALABESSA_CARD_JUICE=false` for the legacy visual path,
or use the local `renderer=flutter` preview comparison. Neither resets game data.
