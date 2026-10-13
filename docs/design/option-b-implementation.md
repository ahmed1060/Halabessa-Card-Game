# Option B implementation

Approved reference: `exec-7aa014b4-7d48-4ecb-86e8-092a04db817a.png`
in the conversation's generated image folder. This is the main Option B design
with the landscape hand shifted left and colourless transparent score glass.

## Visual contract

- Cafe background, purple felt, mint rail, cream card faces, navy/gold/mint backs.
- Local avatar top-left with chat badge; tap it for match chat.
- Partner upper-centre, dealer deck beside the dealer (on partner's left).
- Opponents around mid-table; landscape right opponent clears upper-right pile.
- One local hand at bottom-right; small shared team pile at bottom-left.
- Team pile count tile narrower than its back stack, rival pile below top-right menu.
- Current-round team capture cards above the menu, never collected card faces.
- Settings, reactions, capture history, room code and leave inside the menu.
- Active avatar glow and segmented deadline ring; no standalone turn badge.
- Top display: physically left our score, centre hand/phase within round, right rival score.
- Colourless transparent glass, not black/smoked glass; swipe up to hide, down to
  restore, tap/keyboard/screen-reader action also available. Never reflow the scene.
- Keep real board cards, phase voting/cut controls, animation origins and gameplay
  authority. OS cutouts and native full-screen/orientation preferences stay intact.

## Verification

`flutter test --dart-define=OPTION_B_SCREENSHOTS=true test/option_b_table_test.dart`
produces real portrait/landscape board images under `build/design-review`.
Tests cover physical geometry, RTL, score visibility without reflow, pile sizing,
capture privacy and card taps. Also run the full existing regression suite.

The control checks exercise avatar/chat, menu/settings, capture history and all
four dealer positions in portrait and landscape. Dealer decks must clear the
score display, opposing pile and avatar rings. When the local player deals,
the deck goes below the avatar in portrait and to its right in landscape.

Local review entry point: `tool/option_b_preview.dart` uses the real offline
practice engine without initializing cloud clients or creating accounts/rooms.
Production still uses `lib/main.dart`.

Verification on 2026-10-13: 489 regression tests passed, followed by 10 final
layout/control checks. Browser checks covered 430×932 and 932×430, score
hide/restore, relocated settings and a complete offline round. Static analysis
reported no errors/warnings in the edited UI files; existing informational
deprecations/style notices remain in the older screen/settings code. No native
device build, production deployment or online account/room mutation was made.

This is a responsive implementation using existing assets, not a flattened
generated screenshot. Illustrated background/portraits remain the game's existing
assets; sample card ranks/counts in the mockup are replaced by actual match data.
