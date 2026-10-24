# Desktop presentation review — 22 October 2026

## Scope and verdict

Local offline preview only, on the existing card-interaction branch. No runtime,
rule, bridge, animation, setting, deployment or production-library changes.
UI/UX review protected the approved theme, central play area and physical seats;
game-feel review kept automated evidence separate from subjective approval.

No new reproducible implementation defect was established in this pass. This is
not a complete device or subjective-feel sign-off.

## Evidence

- Existing Unity tab was left on its finished-match screen, unchanged. A separate
  offline tab was used and closed after review; temporary viewport override reset.
- Observed portrait at 393 × 668 and deliberately checked landscape at 1280 × 720.
  Landscape showed centered own hand, horizontal opponent fans, top opponent's
  fan to the avatar's right, circular capture-count badges and a deck-anchored cut
  prompt. The portrait result displayed both teams and scores without clipping.
- Unity console emitted native card contact and completion events and matching
  received acknowledgments. These establish an active native path at observed
  points, not uninterrupted frame pacing for a whole match.
- No warnings/errors returned by the isolated tab's browser-log check.
- Live long-hold/reveal attempts were not conclusive: game progression between
  observations prevented a stable before/after comparison. Do not count these
  attempts as manual gesture acceptance or proof of smooth motion.
- All **63** focused Flutter tests passed with interaction and deck flags enabled:
  `card_interaction_audio`, `card_feedback`, `card_gesture_intents`,
  `shown_card_layer`, `unity_visual_handoff`, `unity_visual_presentation`, and
  `approved_panels_visual`.
- Existing procedural WAVs were exported unchanged under ignored
  `build/sound-review-2026-10-22/`: slam variants 0–2, reveal, cut and shuffle.
  Successful generation/format checks do not establish realistic Foley or user
  sound approval.

Screenshots are under ignored `build/design-review-2026-10-22/`:
`portrait-match-result.jpg`, `landscape-cut-prompt.jpg`, `landscape-gameplay.jpg`.

## Ownership and preserved behavior

- `fanned_hand_widget.dart`: input, private queued selection, hold tremble and
  cancellation; hold build-up starts after 180 ms, pulses every 100 ms, stops at
  marking/cancellation/backgrounding. Actual vibration remains hardware-dependent.
- `card_feedback.dart`: common audio/haptic contact owner; scope-fenced duplicate
  suppression and foreground/preferences checks.
- `multimedia_service.dart`: card/deck presentation ownership suppresses duplicate
  legacy contact paths; local fallback or configured sound override supplies audio.
- `default_audio_assets.dart`: distinct cached procedural reveal/slam sounds,
  not recorded half-card/table-edge Foley.
- Existing Unity action/contact/completion bridge and fallback remain unchanged.

## Remaining acceptance gates / smallest next plan

1. Human desktop review: hold then cancel off-turn, queue until next turn, public
   reveal without consuming a play, and cut/shuffle motion at normal visible pace.
   No source change is justified solely by inconclusive automated clicking.
2. Listen to exported sounds. If the requested physical table-edge character is
   not approved, select/record licensed Foley first; proposed surgical hook is
   the existing SFX override slots, not command or scoring logic. Keep procedural
   fallbacks. Re-run `card_interaction_audio_test.dart` and `card_feedback_test.dart`.
   Rollback is removal of the optional override, restoring the present fallback.
3. Android phone: install with explicit data-preservation planning, verify a single
   launcher, normal startup, Unity motion, reveal/slam, hold vibration cessation,
   audio contact latency and background/resume. No phone available yet.
4. Mac/iPhone: compile the fresh isolated iOS export and verify the same native
   launch/resume/audio/haptic behavior. Source export and CI are not device proof.

No new push or deployment was performed. See `native-qualification-2026-10-22.md`
for the two ARM64 debug APKs and the isolated iOS export qualifications.
