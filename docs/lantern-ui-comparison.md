# Lantern Nights: design comparison and verification

The approved G1–G6 boards were recovered from the original conversation on
3 October 2026. They are the visual reference, not the earlier generic felt UI.
Arabic branding is **حلبسه**.

## Implemented in this revision

- G1: illustrated café framing, illustrated seats, mint/team and rose/rival
  scores, cream fanned cards, current dealer's adjacent closed deal deck,
  one closed collection per team, own-team face-up last capture and current-round
  played-capture-only history. Round-end leftover awards do not create a fake
  played card in that history. Captures gather, flip, and travel to the measured
  pile; deal flights originate from the measured dealer deck.
- G2: guest-first welcome, labelled providers, stacked lobby actions and bounded
  create/join forms. Existing authentication and valid room-code rules remain.
- G3: adaptive seated-player cards in the waiting room; one branded results
  surface with team-colored scores. Existing ready/vote/replay permissions remain.
- G4: shared café/brand frame for profile, leaderboard, store and owned inventory.
  Store categories and owned/equipped state remain based on real data.
- G5: branded social/settings/rewards; cream chat pane with legible sender labels;
  independent persisted reduced-motion setting. Reward pending state no longer
  falsely claims success before the server confirms it.
- G6: static illustrated reconnect surface and a rules/help page reachable from
  settings. Rules describe matching the top rank to capture the entire board,
  not suit matching or invented Jack powers. Account controls remain in profile.

## RTL cause and correction

Directional Rows mirrored the seat layout while animation fallback coordinates
still assumed physical left/right. Physical table seats now have a stable LTR
coordinate frame. Each played card's owner is resolved to a relative seat and
its actual RenderBox is converted into the board's coordinate space. Text and
directional controls continue to follow the selected locale.

Tests cover seat origins in RTL and LTR, phone/desktop sizes, and 100%/200% text;
collection history, round awards, reduced motion and existing gameplay tests.

## Visual checks

Browser checks at 1191×668 and 390×844 covered the lobby, bot table, store,
inventory and settings. An Arabic portrait bot table confirmed unchanged physical
seat identities with mirrored text/control layout. The current code intentionally
uses real currencies, products, player names and phase rules rather than copying
illustrative/mock data in the design boards.

This is not a claim of pixel-identical raster reproduction: mockup artwork,
dynamic player content and text sizes differ. Nor does browser/widget verification
certify Apple/Google store acceptance or replace native-device testing.
