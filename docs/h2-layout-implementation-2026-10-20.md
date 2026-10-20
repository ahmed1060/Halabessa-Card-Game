# Approved H2 layout and seamless timer

The user approved H2 on 2026-10-20. Implementation is local only in
`build/lantern-remote-final`; no commit, push, deployment or Unity embed promotion.

## Presentation-only changes

- `option_b_table.dart`: center the local fan horizontally while preserving its
  previous height, card size and expanded spread. Center the board region on
  the table. In portrait play, seat Bot 2 beside the deck and keep the menu at
  the far-right edge to leave space for its side hand. Pre-deal retains the
  earlier avatar slot so the approved cut popover stays unobstructed.
- `table_seat.dart` and the existing board call site: only relative seat 2 uses
  the right-side public backs/count. Retain existing dealing animations, avatar
  interaction, count semantics and hidden-hand privacy. Compensate for the
  presence/absence of the dealer label, so the hand does not jump into history.
- `turn_deadline_ring.dart`: Option B uses a closed circle with radial liquid
  shading. Its thickness is `5 * remaining`; its circumference never opens or
  divides into segments. It disappears at zero. Other ring consumers keep their
  prior progress-indicator presentation.

The original clock, expiry, server correction and reduced-motion update paths
remain intact. No new audio, haptic, queue, timing or bridge messages were added.
Flutter and Unity use the existing shared `OptionBGeometry` normalized anchors.
No Unity rebuild is necessary for those placement changes.

## Checks

- Pixel sampling around all 360 degrees at full, half and low thickness detects
  cuts; the zero-time image is transparent. Clock correction and reduced-motion
  tests preserve the real remaining time, rather than restarting a countdown.
- Geometry checks assert table-center board, centered hand, original hand
  height and non-overlap. Actual board tests check the side hand against the
  history/menu for all four dealer positions in portrait and landscape.
- Deterministic actual-screen renders use test-only fixtures, never injected
  into production or online state. See `build/design-review/tabletop-*-play.png`.
- Live Unity preview checks are separate from Flutter fixture renders. See
  `build/design-review/h2-live-{portrait,landscape}.png`.
- Full regression results: `build/h2-full-tests.log`; scoped analysis:
  `build/h2-analysis.log`; local web build: `build/h2-build.log`.
  Final full regression run: **546 passed**. Scoped analysis: **no issues**.

No domain, commands, scoring, bots, ownership, voting, deadlines, or Unity source
were edited in this pass. Existing unrelated work was preserved. The safety,
planning, hybrid-card-feel and UI-review skills guided these boundaries.

Rollback is limited to the H2 geometry/call-site/ring hunks; do not reset files
containing other approved changes. The Flutter fallback renderer remains
available via `?renderer=flutter`; it intentionally uses the same H2 layout.

The generated mockup is a placement/material direction, not evidence of exact
pixel equality. Existing runtime artwork/fonts remain in use. Native phone
testing is not certified by the browser or widget tests.

## Approved branch publication

After local review, the user requested a push on 2026-10-20. The approved UI,
source assets, tests and verified WebGL renderer are prepared for publication
on `codex/option-b-final-layout`, not a merge or deployment to `main`.
The four files in `web/Build` were copied from the reviewed isolated export and
verified by SHA256. Existing Android/iOS binary exports remain unchanged and
are not certified for the new Unity visual features. The orientation document's
Firestore rule still requires emulator allow/deny verification before deployment.
Earlier local-only statements in the review documents describe their audit time.
