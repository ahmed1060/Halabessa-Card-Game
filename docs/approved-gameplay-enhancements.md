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

Server-policy foundation implemented and regression-tested, **connected to the
command endpoint but not the production gameplay controller yet**: deadline-gated manual/timeout
play, three accepted timeout removals, explicit leave, inherited replacement
hands/team, waiting-room vacancy reopening, non-host phase advancement,
round conservation, capture phases, scoring and bounded rematch votes.
The full backend regression gate currently passes 61 tests. A complete-round
simulation caught and fixed an inconsistent subsequent-hand turn timestamp.
Accepted plays append immutable play history for presentation; capture animation
cannot harvest the same cards twice or consume the next player's countdown.
Reward values remain a preview with `settlementPending`; no reward settlement
or production rules migration is claimed. Do not switch normal gameplay to this
protocol until the command/mirror/privacy/reward migration is verified end to end.

Command delivery integration (219 Flutter / 48 backend tests): commit the SQL
state/ledger before delivery; repair reads the latest committed room while
holding its transaction row lock, so late requests cannot publish old revisions.
Mirror failure returns an accepted result marked `mirrorPending`; an identical
retry repairs delivery without applying another move. Field-level atomic Firebase
updates preserve chat, presence and heartbeats. Responses and version conflicts
return the same-revision public state plus only the caller's private hand.
Client command transport uses one immutable UUID/payload across one bounded
network retry, and does not retry version/validation rejection as another move.
`getMatchSnapshot` is for the SQL command protocol, **not legacy RTDB recovery**.
Production read-only verification found zero accepted commands/versioned rooms
before this change: the existing gameplay controller still needs migration.
No timeout/takeover activation in normal gameplay or private-hand rules rollout
is claimed here.

Approved live private-room verification passed on 4 October: four temporary
guest accounts filled seats 0, 2, 1, 3; two simultaneous card commands accepted
exactly one move and rejected the other with a version conflict. Retrying the
accepted command after another turn returned current revision 6 with original
applied revision 5, without replaying it. Chat and presence survived delivery.
The temporary Firebase accounts/match data and SQL room/profile records were
removed afterward; an expired private lobby-index entry may await cleanup.
This verifies the command transport, not migration of the existing controller.

Lifecycle command endpoint integration (Supabase function revision 17): the JWT
caller cannot proxy another human or bot. `advance` lets any seated human request
server-timed preparation, bot moves, timeout moves, capture completion, scoring
and voting progression. Manual plays/cuts use deadline checks; compatibility
phase commands cannot skip delays. Leave and bot/shuffle/rematch votes use the
same command ledger. Active rounds clear the waiting-lobby expiry. Reward
settlement remains pending and cannot be bypassed by a unanimous rematch vote.

Versioned room joins lock SQL state/secrets, never import the Firebase mirror,
preserve reconnect identity, and atomically claim eligible released public seats.
Waiting joins keep opposite-teammate priority and invalidate old bot votes.
A legacy join racing the first command cannot overwrite the new SQL revision.
The updated private-room live concurrency smoke test passed again against
revision 17, including the five-second dealing gate; its temporary accounts,
Firebase match and SQL room/profile/command records were removed afterward.
Released-seat joining is regression-tested but not yet exercised in a live UI.

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

Implemented (207 Flutter tests pass; physical-device verification remains):
visible own-turn countdown, saved landscape-default/native orientation preference,
non-scrolling standard-text phone-landscape table, removal of the rectangular
seat highlight, RTL/LTR card-center hit testing at three landscape phone sizes.
The countdown currently reads the existing turn timestamp; the server-deadline
migration remains part of Batch 2. Browser orientation remains browser-controlled.
The reported Safari-wide tap offset has not yet been reproduced on a real device.

- Visible local-player countdown using the authoritative deadline.
- Remove rectangular active-player border; retain circular countdown.
- Persist landscape/portrait preference; native orientation request and supported web fallback.
- Compact phone-landscape layout without routine gameplay scrolling or clipping.
- Preserve team stacks/current-round history/dealer deck and physical RTL seat mapping.
- Measure and repair visual/pointer-coordinate mismatch, including Unity overlay hit testing.
- Validate safe areas, toolbar changes, rotation, keyboard, larger text and reduced motion.

## Batch 4 — authentication and store

Implemented: existing `default_table` now has the Lantern Nights name and asset
in the store; the emerald theme remains available separately. Table fallback
selects by type/ID, never a fragile list index. Existing equipped/ownership IDs
are preserved. Native Facebook App ID/configuration is still missing; requested
from the user. Provider sign-in is not verified as fixed.

Authentication code corrections pass the complete 211-test Flutter suite:
Google explicitly requests the configured web client token; iOS's callback
scheme matches its committed Google client; Google/Facebook guest upgrades
retain the anonymous UID; cancellation and configuration errors are surfaced.
Android CI supports an optional stable, owner-provided private upload keystore
and reports its public certificate fingerprints. No signing secrets were
created or published. See `social-sign-in-setup.md` for the remaining owner
configuration. This does not establish successful provider sign-in on a device.

Catalog audit: every built-in store asset and card illustration exists, and
built-in item IDs are unique. Card-back fallback is now type-safe too; owned
selections are preserved. Built-in translated names resolve when the catalog
is read rather than being frozen in the first language used.

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
