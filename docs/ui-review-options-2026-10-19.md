# UI review options — 2026-10-19

Preview-only image mockups, generated with the built-in image tool. The user
selected **Capture B + Cut C**; neither control redesign is implemented yet.
The real cafe artwork,
rules, cards, seats, and dealer identity remain authoritative in the application;
the cut-prompt context illustrations are not proposed replacement table assets.

## Capture-history options

Both remove the two standalone collected-card piles/count tiles and move their
counts into the top-right capture-history control. Mint = own team; coral =
opponents. Sample card counts are 10 and 6, not match scores. Menu remains below.

- **Capture A:** two-part counter footer below the label.
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-7b860e0d-2d1d-432c-ade6-b696c083be1a.png`
- **Capture B:** shorter single row with a mint count, label and coral count.
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-efd4fa56-d0d1-40ea-b39f-0b13331c863e.png`

Compare the capture control only; AI-generated surrounding boards are not new
geometry specifications. Preserve the actual small deal deck and all four seats.

## Cut-prompt options

Keep the same existing title, instruction and cut action; these are visual
treatments, not rule/cut-ownership changes.

- **Cut A — Compact ivory:**
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-930c13ae-9892-4147-ac60-a044b5aef81c.png`
- **Cut B — Clear glass:**
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-518572d3-b9fe-4ca1-8a9e-d53ac92ed88d.png`
- **Cut C — Deck-side popover:**
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-5e037a4d-732c-4f2d-8bad-10db0376bf6e.png`
- **Cut D — Slim bottom tray:**
  `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-4d56452e-93f8-4de9-80ac-b93fe55fe4f7.png`

## Separately approved small runtime changes

- `game_board_screen.dart`: scale the entire deal-deck indicator to .5 about
  its top centre, preserving the reserved slot and transformed deal origin.
- `match_choice_panel.dart`: ivory vote-button label on explicit ink fill,
  including pending/disabled presentation. No vote/countdown behavior changes.
- `table_seat.dart`: suppress the seat-wide InkWell tint/splash and paint hover
  only on the circular avatar. Keyboard focus uses that circle too. Existing
  click target, callback, active-turn cue and tooltip are preserved.
- Tests: `match_choice_contrast_test.dart`, `table_seat_hover_test.dart`, and
  deck-scale assertions in `option_b_table_test.dart`.

No changes to Unity scripts, bridge messages, domain logic, server timers,
scoring or voting. Local preview only; no commit, push or deployment.

## Verification of approved changes

- Targeted vote/scale tests: 18 passed; targeted hover/contrast/layout checks:
  13 passed.
- Full Flutter suite: **518 passed**, saved in
  `build/avatar-deck-vote-full-tests-2026-10-19.log`.
- Local release web build succeeded and the existing isolated Unity WebGL
  artifacts were restored. No new Unity/native build is claimed.
- Browser reloaded at http://127.0.0.1:9111/?renderer=unity. The deal indicator
  is visibly half-size. Moving the pointer over the left avatar shows a circular
  coral cue and the existing tooltip, with no rectangular seat tint.
- Proof: `build/avatar-circle-half-deck-2026-10-19.jpg`.

Capture B and Cut C are selected. The user then requested a full-game mockup
using Cut C's plum felt, fine gold detailing and warm wood frame. That new
global art direction remains a preview pending review, not a runtime change.

Combined portrait/landscape/selected-cut-detail mockup:
`C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/exec-81478088-4606-4031-8dee-57aaaa7038c6.png`
