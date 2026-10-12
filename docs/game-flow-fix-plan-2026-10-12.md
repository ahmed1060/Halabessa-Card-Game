# Game-flow latency fix plan — 12 October 2026

Status: implementation and isolated canary complete; combined release prepared. The final server is deployed without temporary QA endpoints. Automatic progression remains gated until the verified client release; deployment/activation status is reported separately from these source-controlled results. This is not a claim that the one-second remote-visible target or physical-device qualification is complete.

## Implementation checkpoint — 12 October

Post-release pacing adjustment: after the user found the rollout too fast, ordinary bot thinking is now 800 ms (previously 450 ms), and automatic last-card play is 900 ms (previously 600 ms), consistently online and in Training. Manual card taps stay immediate, capture presentation remains 600 ms, and server-driven/atomic capture progression stays enabled. Earlier measurements below describe the original rollout, not a benchmark of the adjusted pacing.

Additional user feedback: removed the pending hourglass badge from hand cards while retaining request guards, selection outline and accessible pending status. Mobile-web input alignment is hardened by initializing Flutter in a single untransformed host synchronized to VisualViewport size and document-relative origin, with coalesced resize/scroll/rotation/resume updates. The SDK's full-page path fixes the body and uses document client size on iOS; the custom host instead shares one measured rectangle for drawing and hit testing. This is a code-confirmed risk and a tested mitigation, not a reproduced or proven physical-Safari root cause. Keyboard, toolbar and rotation cases have regression coverage; the exact reported phone issue still needs a physical-device retest.

The user clarified that the web offset is present on first load and clears after portrait–landscape–portrait rotation. Startup now measures immediately, on the next paint, on page load, and after engine initialization/app mounting, without waiting for rotation. Native orientation is owned by an app-root scope, restored from saved preferences before Firebase startup, and reapplied on settings changes/resume. Match routes no longer set or unlock orientation. Landscape remains the default, portrait persists, and the English/Egyptian/Saudi settings copy explicitly covers all app screens. Browsers retain physical rotation control; no canvas transform or pointer-coordinate adjustment is used. Large-screen Android/iPad OS restrictions still apply.

Verification for this adjustment: 465 client tests and 242 backend/web tests pass; the release website builds, the Edge entrypoint typechecks, and the new orientation controller/tests have no analyzer notices. The full analyzer passes the existing errors-only release policy, with pre-existing warnings/info still outstanding. Native platform-channel tests cover Android/iOS initial preference, navigation, changes, resume and non-mobile exclusion; they are not physical-device certification.

Local release-browser verification: at 430×932 on the initial load, the host/view have the same vertical origin and height, the body is untransformed, and the visible settings button opens at its center. Existing-account offline Training renders at 932×430, a center tap plays a card and advances the turn, and resizing back to portrait preserves host/view alignment. The revised settings explanation is visible and the pending card badge is absent. This desktop browser-size test cannot reproduce iOS browser chrome or certify the physical iPhone fix. Backend v65 is ACTIVE; all 33 deployed files match the prepared release, with only the pacing-policy file changed from v64.

Implemented:

- Durable, private deadline jobs and a bounded automatic server worker using the existing locked engine, including a disabled global/canary switch and inactive repair schedule. Sleeps and mirror delivery happen outside room locks/database runners; retry penalties are fenced to the failed revision.
- Ordinary bot eligibility and Training thinking set to 450 ms; the separate 600 ms forced-last-card rule remains intact. Training's generic settling/random thinking pauses are removed. Delayed Training tasks now check disposal and room generation before accessing state.
- Smooth isolated avatar rings, including bots in timer-free rooms, forced-card duration and reduced motion. Expired rings stop ticking and restart only when their deadline/clock changes.
- Bounded exact-command receipts in accepted snapshots. A matching fresh feed receipt releases its pending play before a late HTTP reply; unrelated updates do not. An old reply/failure cannot release or penalize a newer pending request. Version conflicts reconcile without the blanket two-second cooldown.
- Managed-room repair watchdog with narrow staggering and coalesced retries; legacy rooms retain their compatible fallback.
- Avoided per-command profile synchronization for already-provisioned participants. Both deletion guards remain unchanged and uncached.
- Adjusted online presentation/request clock from Firebase's server-offset information, monotonic elapsed time after calibration, reconnect/resume refresh, and isolated ring recalibration. The offset remains an estimate, not proof of subsecond clock accuracy or permission to bypass server deadlines.
- Fixed-category command/worker timing diagnostics with no room/user IDs, private cards, tokens or chat. Worker engine time is separate from deliberate waits; diagnostic failures cannot roll back accepted moves.

Second-batch completion:

- Capture and next-turn authority commit together when every current human controller declares capture presentation version 2. Bounded, ordered public-card events drive only local table artwork. Legacy controllers retain the compatible 600 ms capture phase. Reconnect avoids replaying old effects; reduced motion skips animation. Capture events reset each round and are anonymized during account deletion without losing cards.
- Cosmetics have a separate, coalesced lane behind gameplay. One fresh-ID retry is allowed only after a definite version rejection proves the same card/turn is still legal; ambiguous acceptance retains the original ID. Waiting for server confirmation is explicit rather than a fake full bot timer.
- Worker chains reuse their own committed next-deadline hint to avoid an extra read-only connection per move. Every execution still reacquires the room lock and checks the current job/revision/deadline. No socket/lock is held while sleeping or publishing. Private recovery is routed to London like released commands.
- One approved guest/private fixture was reused for all retries, baseline and canary checks. No additional guest or room was created. The fixture, profile, private cards, command ledger, publication and progress jobs were deleted; identity absence was verified. Four small non-personal Firebase tombstones remain intentionally to fence delayed publication. Temporary fixture recovery and cleanup endpoints were removed before final deployment.
- Live QA verified autonomous bot/forced-card chains with zero client advance requests, one manual atomic capture, reconnect, duplicate-command identity, durable cron recovery after bounded-worker exhaustion and 52-card conservation. Existing players and matches were not used as test fixtures.
- The un-routed legacy baseline needed a longer test timeout because each bot requires a separate request. The first canary exposed an inactive repair schedule after a 16-step chain; enabling the gated repair schedule recovered it. The schedule is only recovery, at minute granularity; healthy clients retain a coalesced 1.5-second watchdog for exceptional recovery. Intentional deal/scoring/cut periods were preserved.
- Browser Training was inspected in RTL portrait and 932×430 landscape, including the dealt board/dealer stack and multiple continuing rounds. Widget tests cover countdowns, capture ordering, physical card origins and reduced motion. This is not a physical iPhone/Android test or a four-human live match.

Qualification still needed: physical iPhone Safari/installed iOS and Android smoke tests, realistic four-human/load testing, and a larger same-network before/after latency sample. The provisional remote-visible p95 ≤1 second target was not achieved by the four-play desktop sample. The mandatory uncached deletion guard remains; removing it to improve a benchmark would weaken account deletion guarantees.

### Verification checkpoint

- Full Flutter suite: 453 passing tests.
- Full backend suite: 233 passing tests; final complete Edge entrypoint typecheck passed after temporary endpoints were removed.
- Release JavaScript web build succeeded. Its WebAssembly dry-run warns about existing web dependencies; this is not a successful WebAssembly build or a physical Android/iOS test.
- Static analysis exited successfully under the repository's error-only policy; existing warnings/information notices remain, so this is not a lint-clean claim.
- Applied migration recorded remotely as `20261012072009_durable_room_progress`; the original CLI-generated local migration was aligned to that verified remote history version to avoid a future duplicate application.
- Both remote migration versions are aligned locally: `20261012072009_durable_room_progress` and `20261012082710_regional_progress_recovery`. QA checked private RLS, no client job-table access, no waiting SQL locks and no retained application sockets at sampled instants. No load/capacity guarantee follows from these small samples.
- Security advisor reports an informational [RLS enabled without a policy notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) for the new private job table. This is intentional deny-all client access, independently verified by privilege checks; no permissive policy was added to silence it.
- Performance advisor notes the new deadline index is [unused](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) while scheduling is disabled; retain it for the planned due-job query. Its existing [unindexed canary foreign key notice](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) concerns the one-row configuration table, not a new room/job lookup regression.
- Four-play desktop samples (nearest-rank p95; small n, not a phone benchmark): legacy automatic routing acknowledgement median/p95 1,136/1,175 ms, own private-view 1,806/1,835 ms; initial canary automatic routing 1,173/1,306 ms and 1,908/2,052 ms; canary using the released client's London route 725/882 ms and 1,170/1,337 ms. These differently routed samples are NOT a controlled before/after speedup claim. Private-view delivery is not measured next-human actionability or paint time.
- In London canary logs, automatic bot due-to-commit delay was 49–165 ms, engine computation 0–1 ms, and forced-card delay 147–154 ms. Four manual server requests took 484–515 ms, including an uncached deletion guard of 277–299 ms. Rendering/animation safety is unit/browser tested, not a recorded sub-100 ms physical tap measurement.
- Token-bearing temporary HTTP diagnostic response records are expired and private. An attempted exact-record deletion was rejected twice by the connector with an expired request-state error; no broader cleanup or permissions bypass was attempted. The test identity itself is deleted, tokens no longer authorize it, and the temporary endpoints are gone.

### Activation, resource bounds and rollback

- Release order: deploy the compatible server, apply private migrations, run the isolated canary, remove temporary tools/fixture, push the client and tests together, verify Hosting and mobile build workflows, then enable `progress_enabled` and the existing `halabessa-match-progress` repair job. No room reset/backfill or paid service is required; existing protocol-1 rooms acquire jobs on their next accepted version change.
- Work is bounded to 16 transitions/20 seconds per task. The minute repair sweep selects at most eight due rooms and sends no HTTP request when none are due. All-bot/unfilled/closed rooms do not schedule endless progression. Normal bot chains reuse the initiating function request instead of requiring one new Edge invocation per client advance. This limits work but is not proof of unlimited free-tier capacity; watch pending jobs, retries, locks, delivery errors and the provider usage dashboard as real traffic grows.
- Stop scheduling immediately with `update halabessa.publication_worker_config set progress_enabled=false,progress_canary_room_id=null where singleton=true`, then deactivate the named cron job. Locked workers recheck the flag; clients retain their compatible progression fallback. Clear disabled queued jobs only if deliberately requested—never delete rooms/accounts as rollback.
- Keep the private schema/migrations in place when rolling code back. Restore the previous Edge source/build from Git if needed; external publication fences, command receipts and server validation remain mandatory. Capture capability version 1 uses the legacy phase, while new clients can consume both phases and events.
- The manual QA harness refuses to run without explicit `--live --fixture-tools-installed`; its temporary, exact-fixture endpoints are NOT part of the released API. Future live fixtures require separate human authorization and scoped teardown tools.

## Scope and evidence

This plan covers the latest turn-handoff, capture, bot-pacing and countdown investigation, including related recovery and timing defects. It is not a claim that every historical release task has been re-audited.

Inspected client/server baseline: commit 238542545438a485128de7b604b6c631c36134ac. The production Edge Function was ACTIVE at version 59 when checked on 11 October.

- Immediate local card artwork uses a 220 ms flight. It does not commit a new turn.
- Online bot eligibility is 1,000 ms, then a human client must submit an advance command.
- Captures hold a 600 ms server phase, then require a separate completion command.
- Client progression ticks every 250 ms, waits while its command is busy, and staggers fallback callers by 1,500 ms per human rank.
- An HTTP request can remain busy after its accepted realtime snapshot arrives. Transport recovery can make that interval substantially longer.
- Transition errors, including version conflicts, set a two-second progression cooldown.
- Opponent avatars use the human turn limit and repaint their countdown every second. Timer-free rooms show a permanently full active ring even for bots.
- Training adds a 100 ms settling wait plus 800–2,299 ms artificial thinking time for ordinary bot moves.
- Display/request eligibility uses device wall time without a server-clock offset in these paths.
- Preparation and round-scoring contain fixed waits. Some are intentional viewing/memory periods, not accidental network delays.
- In a read-only log sample from 09:45–10:47 UTC on 11 October, 12 submitMatchCommand operations had total function timing 477–998 ms, median 500 ms. Median deletion guard was 278 ms; median profile sync was 44 ms; maximum measured database admission queue was zero. These are not phone end-to-end timings and do not distinguish card-play from other command types.
- Async acknowledgement was enabled for all rooms; the publication queue was empty at the instant checked. A historical delivery stall is not ruled out by that snapshot.
- 58 targeted Flutter tests and 34 targeted backend tests passed. Existing tests establish correctness for their cases, not production latency or smooth bot countdowns.

## Rules and constraints to preserve

- Remain server-authoritative; no client-controlled turn, score, capture or reward acceptance.
- Preserve private hands, version fencing, idempotent commands, card conservation and exactly-once reward receipts.
- Preserve three-timeout inactivity removal; early bot takeover occurs only on leave/removal.
- Preserve forced last-card play, without treating it as a timeout or manual activity.
- Preserve the hardcoded ten-second human voting window, unanswered votes becoming No, shuffle bots following the human majority with randomized ties, and no independent bot rematch vote.
- Preserve approved RTL seating, capture history, orientation settings and accessibility/reduced-motion behavior.
- No user-data reset, paid upgrade or new paid service. Free-tier consumption is a rollout gate, not an unlimited-capacity promise.

## Phase 1 — Establish the complete baseline

1. Add fixed, privacy-safe timing categories for manual play, automatic bot play, capture completion, forced last card and cosmetic commands.
2. Measure local tap feedback, accepted commit, next-player private-view arrival, actionable next turn, bot due-to-commit and capture completion separately.
3. Capture median/p95, errors, delivery retries and resource use; do not hide remote-view latency behind an early acknowledgement.
4. Measure bot-decision execution separately from deliberate waits. The current strategies are small hand evaluations; do not weaken bot intelligence to address a scheduling delay.
5. Confirm the tested browser/app build fingerprint. Use authorized isolated fixtures for live reproduction, not existing users' records.

Completion gate: reproducible before-values and explicit platform/network conditions. Instrumentation must not log tokens, private cards, chat, emails or room/user identifiers.

## Phase 2 — Put automatic progression on the server

1. Store each pending transition's identity, expected gameplay revision and due time durably with the authoritative room update.
2. Start a short bounded background task after commit. At execution, reacquire the room lock and validate the same phase, turn, participant and due time before applying a move.
3. Continue through a limited automatic chain (bots/capture/forced last cards), publishing ordered events. Stop at an ordinary human decision, room closure, budget limit or superseding revision.
4. Keep database connections/locks released while waiting or delivering network data. Never replay an uncommitted mutation after ambiguous completion.
5. Make duplicate workers and worker/client races harmless. Cancellation is based on durable turn identity, not process memory.
6. Keep durable recovery and a coalesced client fallback. Background runtime survival is not guaranteed; a slow periodic repair worker must not be the normal subsecond turn scheduler.
7. Address human timeout scheduling within the same bounded/durable design, including leave/kick and unanimous/expired vote races. Do not keep a permanent per-room function loop.

Completion gate: consecutive bots progress without a healthy browser sending one advance per move; terminated workers recover without duplicated plays. Validate quotas and runtime limits before enabling production.

## Phase 3 — Separate capture presentation from turn authority

1. Commit a capture and its next-turn eligibility/deadline together, with an immutable presentation event and an ordered gameplay identity.
2. Eliminate the browser-issued capture-completion request from the ordinary handoff path. Keep compatibility for existing clients/capture snapshots during rollout.
3. Play merge/flight locally from the accepted event. Use a compact 450–600 ms animation budget; preserve accessibility and reduced motion.
4. Permit the next legal intent according to server eligibility, without waiting for a second decorative phase publication. Never lose, duplicate or visually reorder a capture when another card arrives quickly.
5. Give the next human an explicit fair deadline, avoiding a timer that silently spends most of its allowance on delivery.

Completion gate: one gameplay command for a manual capture; no separate decorative completion round trip; capture history and all 52 cards remain correct.

## Phase 4 — Unified bot pacing and truthful timers

1. Proposed ordinary bot thinking duration: 450 ms online and Training, independent of easy/medium/hard/expert intelligence. This is a proposed product setting, not an achieved latency measurement.
2. Publish explicit automatic-action due times and use them for the bot indicator, including timer-free human rooms.
3. Drive progress smoothly from an absolute deadline with an animation ticker; update numeric labels at an appropriate lower frequency. Rebuild only the indicator, not the full table.
4. At zero, distinguish waiting for confirmation from remaining thinking time. Do not reset the ring or display a fake full timer while delivery is pending.
5. Remove Training's random multi-second delay and generic settling wait where the single-flight turn guard already provides safety.
6. Keep the existing 600 ms forced-last-card policy initially. Any reduction must remain separate from inactivity handling and receive race tests.

Completion gate: smooth, correctly proportioned timers for bots, humans and forced moves; no static bot timer in timer-free rooms; Training uses the same pacing contract.

## Phase 5 — Remove avoidable request blocking and retry pauses

1. Track pending gameplay intents by command/turn identity rather than one indiscriminate room-wide busy flag.
2. Let an authoritative feed confirmation resolve the corresponding pending move even when its HTTP response is late or lost. A new command is safe only with the fresh revision; never simply unlock on an unrelated snapshot.
3. Give gameplay priority over cosmetic/profile/emote requests while maintaining SQL serialization and server validation.
4. Treat a version conflict as reconciliation, not a blanket two-second outage. Retry only when the reconciled state proves the action is still legal and has not already succeeded.
5. Use separate bounded backoff for real network/service failures, honor server retry hints, and never issue a new-ID duplicate for uncertain acceptance.
6. Replace accumulating fallback-rank pauses with a server-progress watchdog and coalesced repair request. Avoid every client hammering the same transition.

Completion gate: delayed replies, feed-before-reply and concurrent cosmetic commands cannot needlessly stall a legal next move; duplicate/timeout/leave races stay safe.

## Phase 6 — Shorten the trusted backend path safely

1. Examine the per-command Firebase deletion-block read, the SQL deletion check and profile synchronization together. The guard is measured overhead, not permission to remove it.
2. Propose a colocated authoritative eligibility check only if deletion acceptance, revocation and failure races remain fail-closed. Do not cache an unblocked user across deletion acceptance.
3. Avoid profile synchronization on every card command once an equivalent verified onboarding/update path and required foreign-key behavior are proven.
4. Reduce independent SQL round trips where safe; retain transaction pooling, per-room locks, priority admission and scoped rate limits.
5. Keep durable async publication/version fencing. Measure private-view delivery separately; optimize only redundant publication work, not recipient isolation.

Completion gate: blocked/deleting accounts cannot play or recreate their profiles, failure behavior remains safe, and command/private-feed timings improve measurably.

## Phase 7 — Server clock and interruption handling

1. Include server time with authoritative responses/events; estimate clock offset using measured request timing and stable elapsed-time tracking.
2. Use the adjusted clock for countdown display and request hints; the server still decides deadlines.
3. Recalibrate on reconnect, tab resume and device clock changes. Do not extend a turn through local rebuilds.
4. Prevent early advance requests from clock skew becoming repeated errors and cooldowns.
5. Distinguish intentional deal/memory/scoring periods from stalled delivery in status messages. Preserve intentional periods initially; shortening them is a separate pacing decision.

Completion gate: skewed clocks and background/resume do not produce incorrect timers, early requests, skipped turns or an apparent frozen game.

## Phase 8 — Verification and staged rollout

Test matrix:

- Four humans, one human/three bots, mixed teams, all four bot difficulties and Training.
- Consecutive bot turns, manual/automatic captures, final cards, empty hands, new deal, round scoring, shuffle votes, rematch and rewards.
- Manual play vs timeout/forced move, leave/kick vs worker execution, duplicate workers, stale versions and out-of-order publication.
- Private feed before HTTP reply, lost reply, unavailable private feed, delayed mirror, reconnect and worker termination.
- Human timer disabled, skewed clock, app/tab background/resume, RTL, portrait/landscape and reduced motion.
- Mobile Safari/iPhone, Android browser and installed mobile builds where accessible. Report any unavailable physical-device verification explicitly.
- Account-deletion refusal/failure, private-hand isolation, exactly-once rewards and free-tier resource use.

Provisional acceptance targets (to validate, not guarantee on every connection):

- Tap feedback within 100 ms.
- Warm manual tap to next-player actionable turn: p95 at or below 1 second in the agreed QA network conditions.
- Healthy scheduled bot eligibility to authoritative commit: p95 at or below 250 ms, excluding delivery; measure remote-visible bot duration separately.
- No avoidable idle gap after the capture presentation; capture handoff must not incur a second browser/server request.
- No duplicate card, skipped round, private-hand leak, falsely credited reward or deletion-guard bypass.

Release order: baseline instrumentation, compatible server/worker migrations, local race/resource tests, isolated canary, client rollout, mixed-version verification, then wider activation. Keep scheduler/publication switches and a tested rollback route. Do not declare completion based solely on green builds.

## Documentation consulted

- Supabase changelog: https://supabase.com/changelog
- Background tasks: https://supabase.com/docs/guides/functions/background-tasks
- Worker timeouts: https://supabase.com/docs/guides/troubleshooting/edge-functions-worker-timeouts-and-websocket-drops

The Supabase and Postgres performance skills informed the bounded-worker, durable-recovery, short-lock and fail-closed verification gates. No implementation, production mutation or new live QA account was performed while initially drafting this plan; subsequent local implementation is recorded in the checkpoint above.

- Firebase server-offset documentation: https://firebase.google.com/docs/database/flutter/offline-capabilities#clock_skew
