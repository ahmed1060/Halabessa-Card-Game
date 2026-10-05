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
- User-data reset is deferred until the UI plan is finished and verified.
  Preserve the administrator account. Resolve the exact identity and data
  scope, then obtain final confirmation before any irreversible deletion.

## Current verification checkpoint — 5 October 2026

The batch notes below record incremental implementation history, not current
release certification. The server-command controller, private-hand rules and
exactly-once reward settlement are implemented and tested. Normal production
room creation remains on the legacy protocol until the staged UI migration
has completed; `HALABESSA_SERVER_MATCHES=true` enables server rooms for QA.

- Current regression gates: 265 Flutter tests and 80 backend tests pass.
- Previous published commit `db1cf200` passed Android, iOS and Hosting CI.
  The iOS artifact is unsigned, not an App Store-ready signed release.
- Private browser QA entered a server room, filled bots, dealt successive
  hands, accepted card-center taps, showed current-round capture history,
  and retained the orientation preference across settings visits.
- Browser QA exposed a Riverpod write during widget construction. Moving
  the animation-origin reset to the mounted post-frame callback fixes startup.
- Landscape capture-history height now accommodates full card faces and
  controls. RTL physical seats remain stable in the tested viewport.
- Server reactions/profile presentation use caller-scoped commands, never
  client whole-match writes. Reactions expire locally after three seconds.
  Cosmetic validation is not proof of purchase entitlement.

Remaining release gates: complete staged browser results/rematch/recovery
verification before enabling normal server rooms; real iPhone/Safari rotation
and touch checks; successful Google/Facebook sign-in on web and Android with
owner provider configuration, native Facebook credentials and stable Android
certificate fingerprints. These cannot be certified by layout tests alone.

Temporary private browser fixture `KTD16855` and guest
`iLMjc96TZ9NsZsCW3iQyb26iLI33` still need cleanup. A proposed narrowly scoped
temporary privileged cleanup endpoint was blocked by safety review and was
not deployed. Explicit owner approval is pending; no such endpoint is present
in the committed client or permanent function source.

Results retry correction: Return home and replay now await their action's
acknowledgement. A rejected request or thrown error restores the controls;
pending requests remain single-shot. Server rematch intent returns explicit
success/failure rather than leaving the results UI latched after rejection.
Regression tests cover pending exit, failed exit, failed replay and vote retry.
The retained private QA room completed a round and recovered after browser
reload; full-match results/replay browser verification still remains.

Landscape results now use a compact two-column summary/score/action layout.
Normal-text replay and home controls fit without scrolling at 667x375,
844x390 and 932x430 with simulated safe areas, in both RTL and LTR.
Portrait and enlarged-text views retain the scrollable stacked layout rather
than shrinking text or touch targets. These are automated layout/tap checks,
not a claim of physical iPhone/Safari or final mockup pixel-equivalence.

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
The full backend regression gate currently passes 72 tests. A complete-round
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

Reward settlement integration deployed (222 Flutter / 72 backend tests pass):
only explicitly created protocol-1 rooms qualify; existing client-controlled
rooms remain on the legacy path. The server freezes reward roster/scores at
completion and derives awards itself, ignoring caller-provided balances or
award maps. An atomic Firestore commit conditionally creates one private receipt
and updates only existing profile statistics with update-time preconditions.
Purchases, diamonds and other profile fields remain untouched. Lost responses,
concurrent settlement requests and SQL rollback after a Firestore commit can be
retried without double-credit. Receipt IDs include the immutable room creation
instant and match sequence to distinguish rematches and reused room IDs.
Pending settlement blocks a unanimous rematch from discarding awards.

Approved private live test passed: four new anonymous accounts and profiles
completed a real four-round/192-play match using protocol-1 commands. Competing
settlement requests and a later retry credited each wallet once, preserved
purchases/diamonds/best scores, and cleared pending settlement. The test's
Firestore profiles/receipt, Firebase match, anonymous accounts and SQL records
were removed. The temporary cleanup action was bound to those exact fixture
IDs, removed immediately afterward, and confirmed absent from the permanent
function (revision 20). No existing players or balances were changed.

Client model/transport now preserves protocol, match sequence and pending
settlement flags. Legacy whole-state publication rejects server-controlled
rooms before changing optimistic local state. A retry-safe settlement transport
is available, but not called by the gameplay controller yet. Normal room
creation still defaults to legacy mode. Private-hand rules and client wallet
writes remain unchanged. Do not claim normal gameplay or full-plan migration
complete from the separate protocol-1 QA test.

Client synchronization follow-up (229 Flutter tests pass): the room protocol is
checked before opening any private-hand subscription. Protocol-1 notifications
fetch the caller's hand and public board together through `getMatchSnapshot`;
heartbeat-only updates do not refetch a delivered revision. Concurrent revision
notifications are coalesced, stale responses are suppressed, and cancellation
or deletion invalidates in-flight responses. Failed reads are stream errors,
not room-deletion signals; a later notification retries without a busy loop.
Active-room join responses now retain the caller's returned hand. Seven new
tests cover these read races and cancellation paths. Normal creation remains
legacy until controller command routing and private-hand rules are complete;
this client change alone does not enforce hand privacy on the server.

Controller command routing follow-up (248 Flutter tests pass): protocol-1 plays,
cuts, bot-fill votes, shuffle/rematch votes and timed progression now submit
intent instead of publishing locally computed snapshots. A due-time scheduler
asks the server to advance; it never selects a bot/timeout card. Server rooms
skip client deck reconstruction, host presence mutation, local autoplay and
bot decision logic. Settlement uses the trusted receipt endpoint; delayed
responses cannot roll back newer revisions or another binding. Pending human
intents wait for the current request and use its accepted revision. Explicit
leave retries definite version conflicts at most twice; removed seats clear
local recovery without sending a second leave/penalty. Stream removal delivers
only public state and never fetches a kicked player's former private hand.
Legacy rooms/offline practice retain their existing execution path.

Still gated: private-hand/state-write rules, active public room index, cosmetic
profile/emoji intents, error/leave feedback and end-to-end server-room UI tests.
Profile/emoji full-snapshot writes are disabled in protocol-1 rooms until their
intent routes are ready. Do not enable normal protocol-1 creation yet.

Private-match rules follow-up: protocol-1 client game-state/hand writes are
denied, including root multi-path attacks and marker downgrades. A seated
player can read only their own hand child; parent and opponent-hand reads are
denied. Only own presence/heartbeat and bounded, append-only, authenticated
sender chat are client-writable. Released players lose private reads and
presence authority. Unknown protocols fail closed. Legacy/unmarked room writes
and atomic public/private updates remain compatible; clients cannot promote
them to a trusted protocol. This deliberately does not secure the legacy
gameplay/economy while that migration is still gated.

All 15 isolated emulator tests passed locally (10 RTDB, 5 existing Firestore).
The Hosting workflow now runs both suites before deploying any Firebase rules.
No production users/data were used by these tests. On this Windows host the
portable Java runtime needed a process-local Unix-domain temp-path override to
use its TCP pipe fallback; no system settings or production configuration were
changed. Hosting and Android CI passed for the rules-migration commit.

Replacement-index follow-up: backend revision 21 publishes released-seat counts
only for public, playing protocol-1 rooms. Initial bots are not vacancies. Rooms
remain listed during a replacement bot's turn, but Join is disabled until a safe
seat exists; the server rechecks availability atomically and refuses expired
rooms. Rejoining an already-held seat remains a no-op. Quick Match uses the same
availability model. Spectators read only public state, with all hand cards
stripped, and do not send presence, heartbeat, progression or snapshot writes.
This is not a spectator-count tracking feature.

All 78 backend tests and 255 Flutter tests passed; changed Flutter sources have
no analyzer warnings or errors. The deployed endpoint and SQL connection respond
successfully. These are regression checks, not a live replacement-room UI test.
Cosmetics/error feedback and end-to-end UI verification still precede normal
protocol-1 activation; normal room creation remains on the legacy protocol.

Human-command feedback follow-up: rejected and stale actions now emit localized
feedback in English and both Arabic locales. Ambiguous transport/backend failures
ask the player to check the table rather than claiming the play was rejected;
cards are not removed optimistically. Automatic progression failures do not spam
the player. Explicit server-mode Leave waits for acknowledgement; failure keeps
the current table/recovery binding available for retry and duplicate taps send
one leave request. A confirmed server removal takes precedence over a lost leave
response. Late responses cannot clear a newly-bound room. Leave and results-home
buttons navigate only after successful departure. Legacy exit behavior is retained.

The complete Flutter suite passed 261 tests, then the final removal/new-binding
race checks passed in the 13-test controller suite. Analyzer reports no errors or
warnings in the changed controller, screen and tests (existing informational
lints remain). Hosting succeeded for the preceding replacement/spectator batch.
Full protocol-1 gameplay UI tests and cosmetics are still outstanding, as are
owner provider configuration and physical-device verification.

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
