# Capture delay and forced last card

## Findings

The authoritative capture path held `capturing` for 1,200 ms. An `advance`
request at 600 ms only changed `capturingStage`, then a second request was
required at 1,200 ms to clear the pile and start the next player's clock.
Both were versioned SQL commands followed by delivery/publication. The UI
also waited for the first command's stage update before flying the pile.
Thus network delivery was on the critical path of a decorative animation.
The 250 ms scheduler and staggered fallback requests could add more delay.
Offline Training separately contained two 600 ms sleeps.

## Changes

- Local merge/flight staging: 300 ms gather followed by 300 ms flight. Identical
  snapshot rebuilds never restart it; disposal cancels its timer; reduced motion
  skips the flight. The existing table art, team destination and capture label
  are unchanged. Legacy stage-1 snapshots remain supported.
- The server holds captures for 600 ms, then uses one completion command.
  No SQL mutation is needed merely to fly a card. Only the accepted server
  completion clears the real pile and starts the next turn's full timer.
- Training uses the same 600 ms capture budget.
- After 600 ms of an active turn, a hand containing exactly one card is played
  automatically. Online clients request `advance` using public counts; the
  server reads the real hand under existing room/version locks. No client may
  choose another human's card. Works for humans, bots and timer-free matches.
- Forced last-card play neither increments nor resets inactivity counters:
  it is not a timeout and is not proof of manual participation. The existing
  three-timeout removal policy is unchanged.
- Training's controller does the same forced move, checking binding generation
  and complete turn identity after waiting. Manual play/leave cancels stale work.

## Verification and limits

Regression tests cover local flight without stage publication, snapshot rebuilds,
reduced motion, disposal, deadline boundaries, timer-free matches, manual/forced
move races, actor restrictions, one harvest per capture, and Training cleanup.
A full round with 36 manual and 12 forced plays conserves all 52 distinct cards,
performs all three deals, and reaches results without skipping rounds.

Local checks: all 436 Flutter tests and 211 backend/build tests passed. The full
Edge entrypoint typecheck passed. Flutter analysis has no errors; its existing
warning/info backlog is not represented as clean analysis.

This removes one command/publication round trip per capture and halves the
intentional server capture wait. It is not a claim of zero network latency or
a measured physical-device capture p95. The completion command, public delivery,
and any fallback controller still depend on the connection. No database schema,
wallet, deletion policy, paid service or player data changes are required.
