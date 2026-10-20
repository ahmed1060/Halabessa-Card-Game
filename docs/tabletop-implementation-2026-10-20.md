# Tabletop implementation and visual comparison — 2026-10-20

## Scope and result

Implemented the approved landscape/portrait tabletop direction in the active
`build/lantern-remote-final` checkout. This is a local review build, not a release.
The surgical-change and game-UI review skills kept this pass in presentation:
no domain rules, server authority, turn selection, scoring, bot decisions,
command validation, or authoritative deadlines were changed in this pass.

The result is not certified as 100% pixel-identical to the flattened generated
mockup. Table texture, typography, and existing court-card illustrations still
differ. No numerical similarity score is claimed. Exact artwork matching would
require the original separate background/card/font assets or a further approved
asset-production pass; a flattened concept is not a layered production asset.

## Implemented visual mapping

- Clean plum velvet tabletop, gold/wood frame, lantern/tea edge treatment in both
  orientations; central ornament remains unobstructed by permanent HUD panels.
- All three bot hands use the same horizontal fan treatment.
- Larger local hand with shared Flutter hit-target / Unity visual geometry.
- Shared four-card loose-cross table poses in Flutter and Unity.
- Deck remains left of the top teammate; Cut C is a deck-side popover.
- Capture B combines the actual team counts and permitted capture preview in
  the top-right control; standalone collected piles are no longer rendered.
- Existing clear-glass, swipeable score strip and rotation policy retained.
- Orientation selector received the table's gold/navy styling. Superadmin
  visibility permission behavior was not changed.

## File-touch map

Flutter presentation: `game_table_background.dart`, `lantern_card_art.dart`,
`option_b_table.dart`, `table_seat.dart`, `fanned_hand_widget.dart`,
`dealer_seat.dart`, `match_phase_panel.dart`, `local_card_play_layer.dart`,
`board_cards_widget.dart`, and `game_board_screen.dart` beneath
`lib/features/game/presentation/`; also
`lib/core/widgets/orientation_settings_control.dart`.

Unity: managed visual poses in `unity/Halabessa/Assets/Scripts/UnityBridge.cs`
and the default back texture under
`Assets/Resources/HalabessaCards/default_card/back.png`. Texture imported through
the live Editor; no raw scene/prefab YAML editing was used for this pass.
Existing bridge messages, capability handling, fallback renderer, and game input
commands were retained. Motion durations were not retuned in this layout pass.

Tests: `test/option_b_table_test.dart`, `test/local_card_play_layer_test.dart`,
`test/shop_card_artwork_test.dart`, and new `test/tabletop_reference_test.dart`.
The deterministic reference fixture is test-only, not injected into production.

## Generated art and prompt set

Mode: built-in image generation, reference-guided reconstruction. Outputs:

- `assets/images/tables/halabessa_tabletop_landscape_v1.png`
- `assets/images/tables/halabessa_tabletop_portrait_v1.png`
- `assets/images/cards/lantern/ornate_back_v1.png`

Landscape prompt specification: extract only the large top-panel background;
remove avatars, names, cards, decks, numbers, buttons, white margins and lower
inset. Preserve overhead plum velvet, narrow double gold/wood rim, central
arabesque, lanterns, tea and leaves outside the playing area. Edge-to-edge 2.33:1;
no baked-in UI.

Portrait prompt specification: extract the left phone's background only; remove
hardware, UI, cards and people. Edge-to-edge 9:19.5, plum felt, long oval wood/gold
rim, central arabesque, top lanterns, cup bottom-left, lantern bottom-right and
leaves outside the playing area.

Card-back prompt specification: exactly one flat upright card back from the
top-center fan; ivory rounded edge, gold borders, navy field, mint four-petal
flower, gold filigree and corner leaves; approximately .70 width/height;
transparent outside; no suits, numbers, lantern emblem or stack.

These are reconstructed assets, not an assertion of exact original pixels.

## Verification evidence

- Full Flutter suite: **532 passed** (`build/tabletop-full-tests.log`).
- Final deterministic reference renders: **4 passed**, at 1004×430 and 430×932,
  play and pre-deal cut states (`build/design-review/tabletop-*-*.png`).
- Unity WebGL export: **Succeeded, 0 errors, 1 warning**
  (`build/tabletop-unity-build-clean.json`). The warning is intentional: Pipeline
  developer automation is disabled in player builds.
- Clean Unity export's four Build files match the local preview copies by SHA256.
- Live browser: deck-side cut action advanced into play; all bot fans, local
  hand and top-right counts rendered; console check returned no errors/warnings.
- Portrait mismatch under mobile-web QA simulation displayed the full blurred
  rotation guard. Actual physical-device behavior is not certified here.
- Editor's original Windows target was restored; Editor left open.
- Protected domain/functions/Supabase diff check was empty for this pass.

Local preview: <http://127.0.0.1:9111/?renderer=unity#/game>.
The `mobileWeb=1` query is a local QA override for testing the rotation guard on
a desktop viewport; omit it for ordinary desktop review.

No commit, push, deployment, production rule update, or production Unity embed
promotion was performed. Android phone and Mac/iPhone checks remain unperformed.
