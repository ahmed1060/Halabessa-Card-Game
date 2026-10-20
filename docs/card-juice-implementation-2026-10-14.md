# Halabessa presentation pacing and spices — local implementation

Latest local review status: [2026-10-15 playable preview](local-playable-preview-2026-10-15.md).
The chronological notes below are retained; see that report for the later input,
native sizing, startup/route-composition fixes and remaining release gates.

Date: 2026-10-14. Checkout: `build/lantern-remote-final`, branch
`codex/option-b-final-layout`, based on `b41275f4720649e2c008a5bc9d0c795bea69c58b`.

## Scope and status

Flutter presentation implementation is locally tested. After the user installed
Unity Editor 6000.0.69f1 and approved official Pipeline automation, the Unity
scripts compiled and **37 live Editor fixture checks passed** after the approved
artwork/facing follow-up (the original timing pass had 28). An isolated
WebGL export also completed successfully. Embedded Flutter Unity exports and
physical devices are **not yet qualified or updated**. No scene rebuild,
production deployment, commit, push, live QA account, or backend change was
performed. See `unity-editor-verification-2026-10-14.md` for the follow-up evidence
and tooling dependency review.

Later qualification exported isolated Android/iOS projects and passed 12 real
browser bridge fixture checks. A separately approved one-line repair removes a
dangling scene-root reference; real scene objects/components stay unchanged.
An early browser audit found a black canvas, missing skin textures and faces
pointing away from the camera. The user approved repairing these prerequisites;
actual Flutter card art now renders with correct facing. The end-of-frame WebGL
opaque-alpha clear is covered by a guarded visual plugin and explicit browser
qualification. **Do not promote Unity visuals yet:** device/native embedding and
the remaining VFX/layout gates still apply. Export success alone is not visual
acceptance. See the chronological verification report for measured results.

The five project-local skills are available at the primary workspace's
`.agents/skills/`: karpathy-guidelines, create-plan, hybrid-card-game-feel,
game-feel-critic, and cgs-ui-ux-review. They were followed for this pass. The
earlier ranked audit remains in the primary workspace at
`docs/taste-and-spices-audit-2026-10-13.md`.

## What changed

| Presentation surface | Implemented behavior |
| --- | --- |
| Flutter public table | FIFO artwork projection for ordinary plays; accepted hand, scores and turn data remain current. Captures use the existing reading/collection window. |
| Flutter hand | Parabolic fan, spring-driven 1.2x peek/lift, elevated drawing order and bounded velocity tilt. Input layout boxes remain separate from child effects. |
| Local play | Existing immediate 220 ms flight gains an arc/tilt; definite rejection gets a 250 ms OutBack return. Existing uncertain-reply recovery and duplicate-command guards remain. |
| Flutter capture | Contact pulse with 50 ms still beat and 120 ms restrained table-art shake. HUD does not shake. |
| Sensory feedback | One scoped contact dispatcher, sound/haptic settings, event deduplication, audio ownership lease, foreground gating and disposed/old-room cancellation. |
| Unity bridge | Optional protocol-1 handshake; ordered visual actions, contact/completion signals, generation fences, rejection return and normalized physical seat/deck/table/pile anchors. |
| Unity source | Child visual spring peek and tilt; cubic arced flights, capture punch, 120 ms camera shake and a bounded mint/coral burst. Existing root input/colliders and scene remain. |
| Recovery | Bounded FIFO/deduplication, action watchdog, snapshot fallback, renderer/lifecycle reset and reduced-motion paths. |

No shader or new Flutter runtime dependency was necessary. The later approved
Editor automation adds Unity's Pipeline package and its resolved dependencies;
these need native export qualification. Existing Flutter deal motion,
card assets, clear-glass scoreboard and Option B seat/pile coordinates were
retained. CardAnimator, CelebrationManager, serialized scene/prefab references
and game engines were not rewritten. Unity round-win dispatch reuses the existing
CelebrationManager; Editor inspection found its serialized round-win particle
references unassigned. The new card-impact burst is tested independently; native
round-win confetti is not claimed to work. Existing Flutter result effects remain.

## Timing actually used

| Beat | Local tuning |
| --- | --- |
| Ordinary Flutter table arrival | Existing 320 ms cubic motion; table projection settles over 350 ms. |
| Optimistic local flight | Existing 220 ms; no extra wait before dispatching a move. |
| Unity ordinary play | 220 ms flight plus restrained contact settle inside a 350 ms visual action. |
| Capture contact | Contact sensory request 30 ms early, then 50 ms still beat and 120 ms effect. |
| Capture read / collect | Existing 1000 ms hold plus 400 ms collection, total 1400 ms. |
| Invalid return | 250 ms OutBack; reduced motion returns immediately. |
| Unity local-hand deal | 380 ms flight, 70 ms card stagger within one 600 ms visual action. Flutter's existing deal remains unchanged. |
| ACK watchdog | Expected visual action duration plus 350 ms, then legacy-compatible snapshot fallback. |

The queue is bounded to eight pending actions; deduplication retains at most 256
IDs. Old/multiple missed Unity capture events reconcile rather than recreating
history. Flutter fresh-capture filtering remains two seconds. These are local
presentation limits, not network turn timers. Sensory lead is a scheduling target,
not a guarantee of hardware latency.

Preserved domain constants: last-card autoplay 900 ms, bot think 800 ms, deck
reveal 4000 ms, round results 8000 ms, and existing voting/deadline behavior.
The previously existing capture-read input gate was preserved, not lengthened.

## File-touch map

New Flutter presentation files:

- `lib/features/game/presentation/providers/visual_action_queue.dart`
- `lib/features/game/presentation/providers/unity_visual_presentation.dart`
- `lib/features/game/presentation/providers/card_feedback.dart`
- `lib/features/game/presentation/widgets/card_juice_controller.dart`

Small integrations:

- `game_board_screen.dart`: feedback and measured visual anchors.
- `capture_presentation.dart`: reuse visual queue for public artwork.
- `fanned_hand_widget.dart`, `local_card_play_layer.dart`, `board_card_motion.dart`,
  `board_cards_widget.dart`: artwork poses and contact hooks.
- `option_b_table.dart`: scene measurement key only, no coordinate redesign.
- `unity_game_view.dart`, `unity_communication_service.dart`: optional protocol,
  lifecycle recovery and visual return after existing validation rejects a move.
- `lib/core/services/multimedia_service.dart`: narrowly scoped play/capture audio
  ownership; all domain callers and other audio paths remain intact.

Unity additions: `Assets/Scripts/CardJuiceController.cs` and metadata; surgical
extensions to `UnityBridge.cs` and `CardInstance.cs`. No scene/prefab changes.

Protected, unchanged: all Flutter domain files, server functions, rules/schema,
bot/vote logic, card ownership, scoring, winners and turn/deadline authority.
Visual ACKs have no path that advances a match or accepts a card.

## Bridge compatibility and privacy

Existing UNITY_READY, SYNC_STATE and PLAY_CARD messages remain supported. New
effects activate only after UNITY_VISUAL_READY advertises protocol 1. Old shipped
Unity exports keep their snapshot behavior until a new export is built.

VISUAL_ACTION includes scoped event ID, room/match/round/revision, renderer
generation, kind, public board/local hand, physical actor, anchors and effect
timings. No opponents' hand faces are sent. VISUAL_CONTACT and
VISUAL_ACTION_COMPLETE must match the active ID and generation; duplicate and
stale messages are ignored. INVALID_MOVE is a cosmetic return only, never a
retry/second play. An ambiguous transport response uses existing recovery.

## Verification evidence

- Full Flutter suite: **511 passed** — `build/card-juice-full-tests.log`.
- Rollback renderer/input subset: **55 passed** —
  `build/card-juice-rollback-tests.log`.
- New adapters/feedback tests and bridge/Option B regression subsets pass.
- Focused analysis of new adapters and their tests: **no issues found** —
  `build/card-juice-analyze-new.log`. Broader touched-file analysis had
  informational legacy lints; no compiler errors/warnings. Existing localization
  warnings occur in the full suite.
- Release web build succeeds at `build/card-juice-web`. Flutter's Wasm dry-run
  reports existing dependency compatibility warnings; this is a JavaScript web
  build, not a Wasm qualification or rebuilt Unity export.
- C# syntax parser passes all three touched scripts. This checks syntax only,
  and is now supplemented by actual Unity 6000.0.69f1 compilation, **28 live
  Editor checks**, and an isolated successful WebGL build.
- Editor follow-up Flutter queue/bridge/feedback/hand/Option B subset:
  **24 passed** — `build/card-juice-editor-followup-flutter-tests.log`.
- Protected-domain/backend diff is empty. Scoped diff check passes with Windows
  CR-at-EOL handling. Pre-existing analysis/platform registrant changes preserved.
- Review images regenerated and inspected:
  `build/design-review/option-b-430x932.png` and
  `build/design-review/option-b-932x430.png`. Geometry/tap tests cover portrait,
  landscape and physical RTL placement. These are widget images, not devices.

## Remaining qualification and rollback

Completed after Editor installation: source compilation, actual CardPrefab
fixtures, drag configuration/input/drop geometry, interruption recovery,
reduced motion, bounded impact particles, and isolated WebGL export. Tests invoke
pointer callbacks; they do not certify physical touch or Flutter-to-device glue.

Still needed (updated after browser/native export checks):

1. Review the Pipeline/Newtonsoft dependency overlap and native round-win
   particle wiring before promotion; no legacy DLL was removed or disabled.
2. Finish transparent-canvas and real-pointer browser qualification for the
   repaired native artwork; review dense table groups and full HUD/board cohesion.
3. Integrate the isolated native exports and check Android/iPhone
   portrait/landscape, tap/drag coordinates, frame pacing, sensory sync and
   background/reconnect. iOS final compilation/signing requires a Mac/Xcode or
   an appropriate build service. Desktop unit tests cannot certify devices.

Flutter changes are enabled locally by the build-time presentation flag. Rebuild
with `--dart-define=HALABESSA_CARD_JUICE=false` to restore the old card artwork and
Unity snapshot paths. The rollback does not reset any room, account, rule or
server setting. Production remains untouched.

## Follow-up — 2026-10-15

The artwork, facing, bounded startup buffer and WebGL alpha-clear repair are
implemented. Portrait and foreground landscape replays passed 14 bridge/transparency checks each;
direct browser card presses produced VISUAL_PICK. The two additional Editor
checks cover explicit built-in skin selection when a custom fallback exists,
and preservation of exact configured custom skins (37 total). All changes stay
within presentation; rule/state/server diffs remain empty.

**Native drag/drop is not qualified.** Runtime-created DragMe components have
only a release listener in CardInstance.SetupDragging. The library's grab/move
actions require explicit event wiring. A direct EventSystem card press works,
but the attempted browser drag produced no PLAY_CARD intent. Repairing this
legacy input path requires a separate scoped input plan, preserving Flutter's
existing legal-turn/card validation and duplicate-command protection. Do not
change the third-party library or claim working real drag based on callback tests.

The isolated exports passed before the final skin-precedence follow-up. Rebuild
the exports after the remaining input work; do not embed/promote these artifacts
as a final native release. Detailed results and limits are in the verification
report. Android/iPhone hardware, audio/haptics and Xcode signing remain untested.
