# Immediate card-play feedback and aligned hand selection

## Confirmed causes

The online hand previously awaited `playCard` before its accepted private view
removed the card. `BoardCardsWidget` then started its arrival animation. During
the network request the only feedback was a lifted hand card and an hourglass.
Thus the measured command round trip was directly visible as tap-to-flight lag.

The hand's yellow selection border belonged to an outer, unrotated Material.
The card artwork alone was rotated inside the deal animation, so their angles
and rounded silhouettes did not agree (as in the reported screenshot).

## Changes

- A presentation-only flight starts on tap, travels in 220 ms, then waits for
  confirmation. The authoritative hand, pile, turn, score and captures are not
  guessed or mutated by this layer. Only the played hand artwork is masked.
  Offline Training retains its existing local play/capture animation sequence.
- A controller rejection returns the artwork in 180 ms. Confirmed own-card
  arrivals do not replay the same flight. A private view that beats a lost HTTP
  reply is not undone. New room/round/hand/user identities discard old previews.
- Physical artwork and board coordinates are measured through their actual
  transforms, including scaled phone layouts. No RTL seat mapping changed.
- Selection and keyboard-focus outlines now share the card's rotation and deal
  motion. The free Lantern deck's rounded silhouette is matched. Fixed hit
  targets, queued-card identity, keyboard input and reduced motion remain.
- The controller reports acceptance as a boolean, retains its duplicate-command
  guard, and rejects locally invalid phase/turn/hand input before submission.

## Verification and limits

Local tests cover delayed acknowledgement, double taps/swipes, rejection return,
private-view-before-HTTP delivery, late responses after room changes/disposal,
reduced motion, physical scaling, RTL/LTR, and the real phone table layout at
390x844, 932x430 and 740x320. Outline/card geometry is compared directly and
optional PNG review artifacts are rendered with the existing Lantern artwork.

No production accounts, balances or matches were used or changed. This removes
the network wait before local artwork feedback; it does not claim zero network
latency for opponents, capture results or the next turn. Physical-device frame
profiling remains separate from these deterministic widget tests.

Final local checks: 428 Flutter tests and 196 server tests pass; Flutter analysis
has no errors (existing warning/info debt remains); the release web build passes.
The default Lantern hand was also rendered and visually checked in RTL and LTR.
