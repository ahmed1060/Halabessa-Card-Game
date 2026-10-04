# Approved gameplay enhancement plan — 4 October 2026

## Final user decisions

- Three consecutive accepted timeout moves kick the human; a manual move resets the count.
- No second-timeout warning.
- Persistent bot takeover happens only after explicit leave or inactivity removal.
- Temporary disconnection alone must not cause persistent takeover or an early move.
- First two joining humans are teammates: fill seats 0, 2, 1, 3.
- Public replacements inherit the released seat/team at a safe turn boundary.
- Landscape is the default gameplay preference; settings can select portrait.
- Keep the approved Lantern Nights visual language and Facebook button visible.
- Stay on the existing free services; no paid service added.

## Batch 1 — local engine and lifecycle safety

Implemented; 197 Flutter tests and 15 backend tests pass. Pending release/device verification:

- Reject missing/unowned/replayed cards in the Dart engine.
- Copy private-hand lists before applying plays/deals; preserve previous snapshots.
- Guard overlapping local play and round-finalization callbacks.
- Bind delayed callbacks to room, round, hand, turn and turn-start identity.
- Stop host-triggered early moves solely because a human is offline.
- Patch late reward results onto the latest completed-match phase, not an old scoring snapshot.
- Show results during rematch voting; allow one replay vote without disabling Return home.
- Server waiting-seat selection puts the second human opposite the first.

These local guards are NOT cross-client arbitration. Do not mark the duplicate
online move report resolved until Batch 2 and its concurrent-client tests pass.
Reward patching is NOT server-side exactly-once reward settlement.

## Batch 2 — authoritative online lifecycle

- Connect online play to the versioned, idempotent server command ledger.
- Complete server round/deal/scoring/rematch and reward settlement before removing legacy writes.
- Single accepted move per turn across manual, timeout and bot requests.
- Server-owned deadlines and human timeout counters; remove after third consecutive timeout.
- Explicit leave, seat controller changes, safe replacement and reclaim of an unreleased seat.
- Host departure must not stall room progression.
- Public active-room index, replacement availability and atomic seat claims.
- Rules migration must accompany the client/server migration, preserving private hands.
- Keep animations presentation-only; failed/rejected commands cannot skip a turn.

## Batch 3 — mobile layout and input

- Visible local-player countdown using the authoritative deadline.
- Remove rectangular active-player border; retain circular countdown.
- Persist landscape/portrait preference; native orientation request and supported web fallback.
- Compact phone-landscape layout without routine gameplay scrolling or clipping.
- Preserve team stacks/current-round history/dealer deck and physical RTL seat mapping.
- Measure and repair visual/pointer-coordinate mismatch, including Unity overlay hit testing.
- Validate safe areas, toolbar changes, rotation, keyboard, larger text and reduced motion.

## Batch 4 — authentication and store

- Capture actual Google/Facebook errors on mobile web and Android before changing flows.
- Verify provider enablement, authorized domains, callbacks and actual APK signing fingerprints.
- Complete native Facebook configuration; verify iOS callbacks separately.
- Handle popup/redirect recovery and cancellation without losing guest progress.
- Explicit free Lantern Nights catalog item, accurate preview and equipped state.
- Preserve purchases/equipped selections; audit every table/card theme asset.

## Verification and handoff

Regression gates: move collisions/retries/stale callbacks; deck conservation;
inactivity reset/removal; player and host departure; reconnect/replacement claims;
full-match results/rewards/replay; phone layouts and touch alignment; provider
sign-in/cancellation; theme preview/equip/persistence; existing Flutter/backend/rules suites.

Real-device testing is required in addition to automated layout tests. Reference
device: iPhone 15 Pro Max; user reports the layout problem across phone models.
Never claim full-plan completion while any of the remaining batches is unverified.
