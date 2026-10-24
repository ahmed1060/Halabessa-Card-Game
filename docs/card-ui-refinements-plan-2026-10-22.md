# Card interaction and HUD refinements — approval plan

Status (24 October 2026): approved refinements implemented for LOCAL review.
The user approved the annotated bottom-right-counter mockup and selected sound A
(dry paper edge). Verification and remaining qualification gates are recorded in
`docs/card-ui-refinements-local-review-2026-10-24.md`. Nothing has been pushed,
merged, deployed or enabled for public rooms in this implementation turn.
Active checkout: `build/lantern-remote-final`, branch
`codex/card-interaction-startup-polish`, HEAD `a032f765` (merged as `683d5e38`).
Preserve all pre-existing dirty files and prior local qualification artifacts.

## Baseline / evidence and priority

The supplied full-screen image is the public web player, not the flag-enabled
offline QA URL. It does not establish which renderer is selected. Findings below
come from the checked-out release configuration and source; no new public-room
commands, runtime modifications or device tests were performed in this audit.

| Priority | Finding and exact hook | Confidence / effect | Acceptance |
|---|---|---|---|
| P1 | `game_board_screen.dart:56,627,893,913` defaults interaction flag off, restricts features to `OFFLINE_`, and supplies null special-action callbacks otherwise. `unity_communication_service.dart` also fences interaction sync to offline. Hosting workflow builds without interaction defines. | Confirmed configuration; explains an ordinary release having no public-reveal/special-slam action. Current deployed server capability is not established merely by backend source existing. | Test a release-equivalent build and verified supported server path, not only the preview; never silently assume every live room supports commands. |
| P1 | `shown_card_layer.dart:138,151` is `IgnorePointer`, paints miniature copies, and in portrait places them at `g.hand.top - height - 3`; it does not move the owned hand card. | Confirmed mismatch with requested single playable card to the right. | One visible owner card per ID across fan and right dock; same held-card identity remains playable; observers see only accepted public faces. |
| P1 | `fanned_hand_widget.dart:290,469,669` reads base slot geometry, resets drag on release, and uses a fixed peek posture/outline for queued cards; `card_juice_controller.dart` lifts a peek only 12 logical pixels. | Confirmed implementation; discontinuity from release pose is a source-level risk to verify frame-by-frame in both renderers, not a measured jump in this audit. | Off-turn release height remains stable; own-turn flight starts at actual visible release position, without snap-back or duplicate. |
| P2 | `table_seat.dart:129` wraps the full reserved seat in a tooltip, concatenating name and detail. `game_board_screen.dart:657` appends difficulty to the two side-bot names. | Confirmed cause of repeated Hard and over-broad hover trigger. | Bot nameplates contain only Bot 1/2/3; bot tooltip reads Difficulty: Hard (localized), only on actual circular avatar or nameplate. No local-player tooltip. |
| P2 | `option_b_table.dart:605` paints filled circular backgrounds behind capture counts and dark numerals. | Confirmed; opposite of latest requested appearance. | Plain mint/coral numerals, including 0 and multi-digit values; no disc, circle border or number fill. Preserve unrelated hand/deck counters. |
| P2 | `fanned_hand_widget.dart:523,771` paints selected gold outlines and per-card move-count badges. Unity `CardJuiceController.cs:85,104` paints private selection rims. | Confirmed. | Queue shown by raised position only; special-use counters live beside the hand, never on card artwork. Keep usable keyboard focus separate from queue marking. |
| P2 | `CardJuiceController.cs:181` gesture windup is 100 ms, scale gain 20%, flight 200 ms and contact punch about 5.5%. Flutter `board_card_motion.dart:85` uses similarly restrained amplitudes. | Source-confirmed modest motion; user reports inadequate feel. A release without the feature gate does not exercise this special path at all. | Compare special versus normal play side-by-side; stronger windup/impact must be recognizable without sound, without obscuring ranks or shaking the page. |

The previous synthesized slam sample is rejected, not approved audio. Prior unit
passes are baseline evidence, not acceptance of the revised requirements.

## Protected boundary

Do not change legal moves, hand ownership, deck/card totals, turn selection,
scoring/capture eligibility, bot decisions, voting, authoritative clocks or command
semantics. Flutter/server keep their existing authority; Unity consumes visuals.
Revealing does not play/discard a card. Usage stays 3 reveals AND 3 slams per
player across the complete 52-card deck cycle (all three dealt hands), not per
turn/hand. Never reduce displayed reveals to one. Cancellation before an accepted
slam consumes no use; duplicate reveal of an already-public card consumes none.
An accepted disclosure cannot be made private again by cancelling a selection.

## Proposed behavior

1. Capture-history strip: colored text counts only. Remove difficulty suffixes
   from side-bot names. Only avatar-circle/name hover or keyboard focus can open
   the bot tooltip; empty seat space and concealed cards cannot. Suppress the
   local tooltip entirely, while preserving existing click/chat behavior.
2. Swipe up off-turn: store a private queued pose at the released upward position,
   bounded to the usable hand area (target approximately 20–35% card height).
   Keep it raised through rebuilds, opponent moves and focus changes. No gold
   queue outline or Next turn/Cancelled label. Short tap on that card cancels and
   returns it; selecting another replaces it. Preserve existing 300 ms turn-entry
   cancellation window without changing any deadline. Auto-play still requires
   the same card owned, legal phase and actual turn.
3. Swipe up on-turn: continue the same card from its visible release pose/tilt
   into the center stack. Flutter and Unity use the same logical coordinates.
   Do not reset the drag before recording its actual origin. Pending/rejected
   commands retain current duplicate protection and a bounded visual return.
4. Swipe down: lift the card toward the owner, then park it to the RIGHT of the
   remaining private fan, same baseline, with a small deliberate gap. It is the
   same card, not a miniature second copy above the hand. Up to three public
   cards occupy this right dock. Tap, swipe up or hold remain usable there.
   Opponents see the accepted public card lift, flip and land near that player's
   hand area. Public faces plus remaining concealed backs represent the same held
   card total; do not add visual extra cards or change the authoritative count.
   Actual play removes the public representation and moves that ID to the stack.
5. Keep the overall hand/dock envelope centered on the current hand line; reserve
   enough width for all four owned cards and a gap, rather than adding a fifth
   card's width. Portrait may adapt card width/overlap, never move the dock above
   the fan or out of the hit-test/safe area. Do not mirror physical right in RTL.
6. Per the user's subsequent annotated mockup, put two compact remaining-use
   counters in the BOTTOM-RIGHT table safe area, above the rim: amber impact-hand
   icon + 3, then mint eye icon + 2 (example remaining values). No Reveal/Slam text
   pills, enclosing badges or on-card labels. They change only on accepted
   uses; queuing highlights the appropriate counter, not the card. Exhaustion
   emphasizes that counter unobtrusively; normal play remains available. Reserve
   separation from Bot 1, the public-card dock and screen gestures in both
   orientations; counters are not new gameplay buttons. Give screen readers the
   full move name and uses remaining. Printed
   rank/suit/court artwork is not a special-move badge and stays unchanged.
7. Retain hold tremble/haptic build-up until marking, then stop it. Give accepted
   slam a stronger near-camera lift, steep strike and localized stack settle.
   Rework sound as dry paper snap plus short table-edge body, not a synthetic
   scoring chime; prepare audio alternatives for approval. Prefer recorded,
   rights-cleared Foley if available. No paid service or unlicensed download is
   implied. The existing rejected fallback is not treated as final audio.

## Proposed beat sheet (tune locally; not measured approval)

All animations affect presentation only, in both renderers. No global timeScale,
web-host movement, mandatory screen shake or rank-obscuring particles.

| Action | Windup / flight / contact / settle | Curves and sensory owner |
|---|---|---|
| Off-turn up queue | Track finger; on release retain its bounded raised pose, 100–140 ms settle if needed | Ease-out to pose, no action/contact sound; no use spent. |
| On-turn normal up play | No return-to-slot; 180–240 ms from release to center, 80–100 ms settle | Velocity-continuous accelerated flight; one normal contact sound via CardFeedback. |
| Public reveal | 100 ms approach, 220 ms side-flight (observer flip during flight), 50 ms contact hold, 150 ms settle: about 520 ms | Ease-out approach, ease-in arrival; one contact sound/haptic, accepted event only. |
| Special slam | 140 ms lift toward viewer to about 1.5–1.6x, 160 ms fast strike, 50 ms contact hold, 150 ms settle: about 500 ms | Clearly different acceleration/depth from normal play; one sharp sound and optional heavy haptic exactly at impact, localized card/stack compression. |
| Cancel/reject | 120–160 ms bounded return to still-owned position | No public disclosure rollback; no use spent on rejected action. |

Completion is after settle, not at sound/contact. Contact must come from a shared
visual milestone, not competing wall timers. Reduced motion skips zoom, flip,
tremble and strike travel: use stable raised/parked placement and a restrained
contact cue; haptics still honor preferences. Foreground action catch-up is
bounded to one active flourish; accumulated replay settles silently within
180 ms, with a 100 ms watchdog allowance. Snapshot/resume never replays expired
audio or executes a private queued command early.

## Exact proposed file-touch map

New presentation-only files:

- `lib/features/game/presentation/widgets/hand_card_placement.dart`: immutable
  shared card-ID-to-visual-slot projection for private, raised and public-right
  positions; no domain mutations or move-legality decisions.
- `lib/features/game/presentation/widgets/special_move_counters.dart`: small
  dock counters driven by passed accepted remaining values.
- `test/hand_card_placement_test.dart`, `test/seat_tooltip_scope_test.dart`,
  `test/special_move_counters_test.dart`: revised behavior, not another renderer.

Small extensions to existing files:

- `game_board_screen.dart`: names, local-tooltip suppression, accepted public-card
  partition, counters, shared visual anchors and verified feature availability.
- `option_b_table.dart`: numeral styling and allocated hand/dock/counter bounds.
- `table_seat.dart`: tooltip text/scope and concealed-back count separate from
  total held-card count when public cards are laid beside an opponent's hand.
- `fanned_hand_widget.dart`, `card_juice_controller.dart`: retained release pose,
  input from both private/public slots, remove per-card badges/queue rims.
- `shown_card_layer.dart`: public observer presentation; stop rendering an owner
  duplicate when the owner's interactive projection already represents the card.
- `board_card_motion.dart`, `local_card_play_layer.dart` (only if needed for the
  accepted flight origin): continuous release and stronger special delivery.
- `unity_visual_presentation.dart`, `unity_communication_service.dart`: same
  per-card placement/selection on native rendering, retained capability gates.
- `unity/Halabessa/Assets/Scripts/UnityBridge.cs`, `CardJuiceController.cs` in that
  same folder: consume shared placement/pose and improve special motion; one
  active native instance per owned/played card ID.
- `card_feedback.dart`, `lib/core/services/multimedia_service.dart`,
  `lib/core/services/default_audio_assets.dart`: only chosen contact timing/audio
  adapter refinements. Audio assets/registration require a selected sound first.
- `assets/translations/{ar-EG,ar-SA,en-US}.json`: Difficulty: value and counter
  accessibility text. Existing bot difficulty values remain unchanged.
- Extend `test/card_gesture_intents_test.dart`, `test/shown_card_layer_test.dart`,
  `test/unity_visual_presentation_test.dart`, `test/unity_visual_handoff_test.dart`,
  `test/card_feedback_test.dart`, `test/card_interaction_audio_test.dart`,
  `test/tabletop_reference_test.dart`, `test/approved_panels_visual_test.dart`.
- `tool/UnityCardFeelQa.cs`: add release-pose and stronger-motion milestones.
- `.github/workflows/firebase-hosting-merge.yml`: LATER release gating only after
  approval and verification; do not enable features in this planning turn.

Inspect, do not change for presentation: `game_providers.dart`, `match_state.dart`,
`card_feature_state.dart`, game engines, `supabase/functions/halabessa-api/card_reveal.ts`,
`match_commands.ts`, sync transport, existing backend rule tests, saved scene and
prefabs. Do not replace embedded native exports as an incidental mockup change.

## Bridge and release contract

Prefer existing hand-index anchors plus private HAND_POSE/HAND_SELECTION messages;
keep authoritative hand membership/order unchanged. Extend only optional guarded
placement metadata if existing anchors cannot represent a required pose. Keep
legacy messages/exports supported and fall back to Flutter for unsupported poses.
Never send private queue selection to other clients; only accepted showCard data
can reveal a face. Keep room/match/round/revision identity, event IDs and generation
fences; dedupe contact/completion and drop late callbacks. ACKs only release
presentation work; no move, turn or score depends on animation completion.
Retry/timeout cancels visual work and reconciles the accepted snapshot, not a
second show/play command. Background, leave, rejection and new deals clear stale
poses; reconnect restores accepted public slots without replaying disclosure.

The existing server source supports showCard and slam delivery metadata, but this
audit did not certify their deployment. Test them with isolated fixtures/emulators
and release-equivalent client settings before proposing removal of the offline
fence. Do not simply enable a build flag and assume online support. Production
rollout, live backend writes and publishing remain separate approval gates.

## Implementation order after approval

1. Add disabled shared-placement adapter/counter widget and deterministic fixtures;
   retain the old path until the new path is demonstrably correct.
2. Apply the small name/hover/numeral changes. Fix one upward-drag release first
   in Flutter, then match Unity with the same screen coordinates.
3. Add the right-side interactive public slots, observer flips, counter updates
   and all-three-reveals edge cases; ensure one visual card per owner identity.
4. Tune special slam against normal play with a visible A/B clip and separate
   sound samples. Obtain sound/feel approval, not a test-only declaration.
5. Exercise release-equivalent web configurations and supported online commands
   in isolation. Then report proposed rollout rather than silently publishing.

## Acceptance and rollback

- Replay identical accepted traces: same cards, board, turns, scores and winners.
- Pointer mouse/touch/web: both swipe directions from every visible private or
  public slot; off-turn queue stays raised; same-card short tap cancels; own-turn
  drag continues from release; no stale origin or invisible fixed hit target.
- Up to three concurrent public cards per player, all four seats: 0/1/2/3 public
  cards, narrow portrait/landscape, RTL, large text and safe areas. No duplicates,
  stack obstruction, false card totals or rank occlusion.
- Reveals don't change turn/board/held-card membership. A parked card later plays
  normally. Limits persist across all three hands, reconnect and repeated turns.
- One bottom-right icon/remaining-number counter per move type; accepted-only
  changes; no badge on any card or text-pill labels beside the hand.
- Circle/name tooltip hit tests, no square-corner/seat/card triggers, no own tooltip;
  accessible focus preserved. Count 0, 9, 10, 52 have colored text and no disc.
- Gesture-vs-normal slam A/B, audio off, reduced motion, haptics off, duplicate/late
  bridge events, rejection, old renderer, fallback, tab background/resume and load.
- Android/iOS vibration, launch and audio latency remain physical-device gates;
  devices/Mac are still unavailable, so no native acceptance claim is possible.
- Proposed new opt-in presentation flag `HALABESSA_CARD_UI_REFINEMENTS` defaults
  false during development and restores the current projection when off. It does
  not alter server feature policy. Small static HUD edits remain independently
  revertible. Never roll back rules/state to roll back presentation.

## Mockup interpretation

The generated review sheet and slam storyboard are illustrative proposals, not
implemented screenshots or exact card-art specifications. Implementation reuses
existing card art and all unchanged approved HUD elements. The rightmost revealed
card is part of the same hand, not an additional card. Small counter numerals mean
uses remaining (maximum three); the latest revision replaces the earlier labeled
2/3 and 3/3 pills with bottom-right icon/number pairs. Tooltip shown in the detail
crop is conditional on hover/focus only.
Generation used the built-in image-generation tool, preserving the reference
velvet/lantern theme. These previews do not assert animation smoothness.
