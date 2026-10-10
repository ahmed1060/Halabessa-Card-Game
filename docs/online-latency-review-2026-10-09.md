# Online responsiveness investigation and proposed enhancement plan

Date: 9 October 2026. Reviewed source: main commit `3f60ff9c`.
Scope: the user reports lag throughout the online game, not just the table;
offline Training is unaffected. The original investigation is retained below;
implementation and verification updates are recorded at the end. No measured
mobile frame-rate claim is made.

## Outcome

There is measured online request latency, compounded by blocking profile
enrichment and an unnecessarily long move-delivery path. A visual redesign or
reducing all animation durations would not address those paths. Optimize the
existing free-service architecture first; do not buy hosting or replace the
engine merely to conceal the waits.

At the original investigation stage, no runtime source, production configuration,
database records or player accounts were changed. The later approved implementation
and isolated QA changes are documented below.

## Measured evidence

The production version-36 logs for 16:12–16:14 UTC contain 33 successful POSTs:
median Edge execution 1,215 ms; p95 1,633 ms. Eleven successful browser preflights
had median 119 ms and p95 174 ms. One version-conflict response took 1,106 ms.
These are server execution timings, not complete tap-to-animation timings.
All successful current-version requests in that window ran in Zurich
(`eu-central-2`); the database project is in London (`eu-west-2`).

The command ledger in the same recent activity has 10 advance commands, three
play-card commands and one leave. That confirms recent online game work, but
the logs do not identify the action for each HTTP request. Do not attribute
each of the 33 requests or its exact latency to a specific player or action.
Older versions' deletion-worker timing is excluded from this baseline.

At the read-only database check: six connections were present, no
`halabessa-api` idle socket or waiting room-lock request was observed, and the
configured maximum was 60. The preceding 24-hour error aggregation had no
SQLSTATE 53300 connection-exhaustion errors. This is an idle-time observation,
not proof of unlimited concurrency or absence of transient contention.

Accumulated pg_stat_statements averages: room-state/hand queries 3.862 ms,
profile upserts 0.545 ms, command-ledger queries 0.701 ms, social queries
0.032 ms. The room-state family includes a historical maximum of 1,793 ms.
The figures span accumulated statistics, not only the reported session.
Typical SQL execution is much shorter than the observed HTTP path; connection,
network, queueing and external-service waits need separate stage timing.

Six public health-only GETs were measured without authentication or database
work: automatic routing 585/311/299 ms, explicit London 1,052/961/333 ms.
This small sample does NOT establish that forcing London improves gameplay.
Compare authenticated operation types before changing region selection.

Deployed HEAD checks confirmed `max-age=0, must-revalidate` for both the entry
page and Lantern table artwork. The Edge preflight has no explicit
Access-Control-Max-Age. Main JS/bootstrap are fingerprinted already, but the
illustration paths are not. The two table PNGs are about 2.1/2.2 MB on disk;
decoded GPU memory and frame cost were not measured.

## Confirmed source-level amplification

1. **Profile publication waits on unrelated network work.**
   `firebase_auth_repository.dart:155` enriches every Firestore profile emission
   with awaited admin status, then social graph, before publishing AppUser.
   Admin status is cached per UID after success; social graph is fetched on
   every emission even when only coins, inventory or statistics changed.
   Thus shared home/profile/store consumers wait for social data, and asyncMap
   serializes profile emissions. Most non-match calls have no app timeout.

2. **Every ordinary API call has multiple remote prerequisites.**
   `index.ts:382` reads the Firebase deletion block before dispatch. SQL-backed
   calls then connect, check the durable job and upsert the profile even for
   read-only snapshots/social/status requests (`index.ts:426–440`). The upsert
   and guard are correctness/security protections; do not remove them blindly.
   `database.ts:28` serializes admitted work across the isolate; one slow action
   can delay unrelated work in the same isolate. Each admitted request opens
   and closes a database client. Whether the optional pooler is configured was
   not established; no credential was inspected.

3. **A move waits for cross-service delivery after its durable commit.**
   `index.ts:629` awaits mirrorDurableRoom before replying. That delivery takes
   a second SQL transaction/room lock and awaits Firebase PATCH inside it
   (`index.ts:158–177`). It preserves ordering, but adds external-network time
   to both the player's response and the period that the room is locked.
   Simply dropping the lock would create stale/out-of-order mirrors.

4. **Realtime notifications cause another HTTP snapshot read.**
   `command_snapshot_stream.dart:27` fetches the consistent public/private
   snapshot through Edge on each newer notified revision. The initiating
   player also receives that snapshot in the command response, but the stream
   does not acknowledge that response revision, so a redundant fetch can occur.
   With four humans, one accepted revision can produce one command plus four
   snapshot calls. Intermediate capture phases add further revisions/requests.
   Coalescing exists already; equal-version heartbeats do NOT always fetch.

5. **Timed progress and human input share one busy lane.**
   `game_providers.dart:184` waits behind an outstanding request. Every active
   human locally checks progress every 250 ms; only due phases submit commands,
   not four HTTP requests per second unconditionally. Multiple clients can still
   submit the same due transition and contend. Bots wait at least one second,
   captures have timed phases, then additional request/delivery waits accumulate.
   Match transport allows a 20-second request plus one same-ID transport retry.
   The hand's 600-ms tap guard is not synchronized to that real pending request.

6. **Lobby subscription identity changes on rebuild.**
   `public_rooms_list.dart:19` constructs watchPublicMatches inside build.
   Each reconstruction can resubscribe and re-enter Waiting, rather than keep
   an established stream/data view. Parent profile changes can cause this churn.

7. **Rendering/loading risks remain secondary, not proven primary causes.**
   The table watches whole match/current-user state. The catalogue listener is
   not explicitly cancelled; card widgets watch all StoreState. Startup waits
   for all catalogue precaches, including unrelated skins, and treats remote
   catalogue URLs as AssetImage paths. These warrant measurement and scoped
   fixes, but offline parity argues against blaming artwork alone. No physical
   device frame trace or production browser performance recording was captured.

## Approved implementation order

Approved by the user on 10 October 2026. The original investigation above is
historical; see the implementation update below for what has actually changed.

### 1. Establish an action-level baseline

- Add bounded timing for token acquisition, JWT/JWK verification, deletion
  guard, queue wait, database connect, SQL/lock time, commit and Firebase mirror.
- Record operation names, durations, byte counts and revision numbers only;
  never tokens, emails, private hands, request bodies or raw user identifiers.
- Measure cold/warm startup, navigation, friends, ranking, rewards, store and
  room entry; measure tap feedback, durable acknowledgement and remote visibility.
- Use a separately approved private QA fixture for mutation/concurrency tests.
  No existing match or balance is a performance-test target.

### 2. Remove global screen dependency waits first

- Publish the own-profile snapshot without waiting for social enrichment.
  Separate social/admin state, preserve server-owned authorization, default
  privileges to false until verified, and retain sign-out/account-switch guards.
- Refresh social state on explicit demand/social mutation with bounded freshness,
  UID-scoped cached presentation and in-flight read deduplication. Do not cache
  positive authorization or deletion eligibility as a shortcut.
- Give ordinary reads bounded timeouts and visible retry/loading state without
  blocking navigation. Do not retry purchase/reward mutations as generic reads.
- Keep a stable lobby stream and last-known list across refreshes. Dispose all
  catalogue subscriptions and avoid refreshing unrelated profile domains.

### 3. Shorten the common backend path safely

- Compare database-colocated execution against automatic routing using actual
  authenticated reads/commands. If regional selection wins, allow its CORS header
  and document failover; do not hardcode a region based on health-only tests.
- Verify the shared transaction-pooler path without exposing credentials; bound
  admission/queue time and separate latency-sensitive requests from slow cleanup.
  Do not restore idle per-isolate pools that previously exhausted connections.
- Avoid unchanged profile rewrites on every read; bootstrap/update only when
  necessary, with durable deletion guards and trigger refusal still enforced.
- Batch independent social reads into one bounded query/snapshot where practical.
- Add a bounded preflight cache for the existing exact allowed origins; keep
  authenticated responses non-public and authorization enforcement unchanged.

### 4. Remove repeated move-delivery waits

- Reuse accepted command responses and suppress equal-revision state adoption.
- Design an own-hand-only, revision-tagged realtime feed (or equivalent consistent
  public/private pairing); never expose other players' cards or the deck. Retain
  Edge snapshot reads for bootstrap, missed-revision recovery and access changes.
- Acknowledge durable moves without waiting on redundant mirror work only after
  a transactional delivery intent and monotonic, per-room publication mechanism
  exist. Publish promptly; retry failures durably. Avoid one-minute polling as
  the normal gameplay delivery mechanism and never publish uncommitted state.
- Coalesce due advances; use a coordinator/failover policy or server-owned
  idempotent transition semantics so four humans do not race every bot phase.
- Preserve server clocks, actor authorization, versions, exactly-once settlement,
  current-round capture history and the fixed ten-second human voting policy.

### 5. Make interactions feel immediate and isolate repaint work

- Show selected/pending-card feedback immediately and clear it on acceptance or
  rejection. Bind interaction guards to the actual pending intent, not 600 ms.
  Feedback must not fabricate a captured pile, new turn or successful purchase.
- Drive visual capture/deal stages locally from accepted events rather than use
  network round trips merely to advance presentation. Skip safely on reconnect;
  preserve reduced motion and physical RTL seat anchors.
- Profile selector-based rebuilds and repaint boundaries for the background,
  hands, seats and overlays; optimize only measured expensive subtrees.
- Preload only current essential artwork, decode to appropriate sizes and lazy
  load other skins. Cache immutable fingerprinted assets; keep index/manifest
  revalidation and version artwork paths so upgrades never show stale designs.

### 6. Verify and roll out in small measured batches

- Baseline and compare the same scenarios/networks before and after each batch.
- Test delayed/out-of-order/duplicate responses, packet loss, reconnect, account
  switch, deletion refusal, human/bot timeout races, full rooms and leave/rejoin.
- Run Flutter/server/emulator suites and Android/iOS/web build gates. Profile
  native devices in profile mode and mobile web with browser performance traces.
- Deploy compatible backend/rules before clients; retain an explicit rollback
  switch. Recheck the approved Lantern design after rendering changes.

## Proposed acceptance targets, not current guarantees

- Local tap/selection and cached navigation feedback: within 100 ms.
- Warm authenticated ordinary-read/game-command acknowledgement: aim for p95
  under 800 ms on the agreed test connection, or at least 50% below baseline;
  remote-view delivery must be measured separately, not hidden after an early ack.
- Remove per-revision snapshot HTTP fetches from healthy steady-state play;
  automatic advance traffic scales with transitions, not human-player count.
- No blank lobby during profile refresh, unbounded read spinner or silent tap.
- On agreed 60-Hz reference hardware, target at least 95% of interaction frames
  within 16.7 ms; assess supported 120-Hz devices against their smaller budget.
- No duplicate cards/rewards, mismatched private-hand revisions, leaked cards,
  stale mirror rollback, lost inactivity policy, user-data reset or paid upgrade.

## Documentation checked

- Supabase regional invocation and Postgres connection guidance:
  https://supabase.com/docs/guides/functions/regional-invocation
  https://supabase.com/docs/guides/functions/connect-to-postgres
- Flutter profiling distinguishes native hardware/profile-mode and web browser
  traces: https://docs.flutter.dev/perf/ui-performance
- Supabase changelog checked. The announced 15.19/17.11 ltree/legacy-cipher/
  custom-operator changes are not evidence of this lag; this project reports 17.6.

Supabase and Postgres performance skills guided read-only connection, SQL,
queue and transaction checks. They did not cause production changes or weaken
the deletion/session protections.

## Implementation update — 10 October, first batch

Implemented:

- Own-profile Firestore emissions now publish synchronously, without admin or
  social HTTP waits. Admin presentation defaults false until separately verified.
  Social state is UID-tagged, refreshed on opening/mutating the friends panel,
  and polled every 30 seconds only while the panel is open. Same-account refresh
  retains its visible graph; switching accounts never borrows another's graph.
- Lobby stream identity is stable across profile/balance/social rebuilds. The
  catalogue subscription is cancelled on disposal; errors retain its last data.
- The backend transport reuses one native HTTP client. Identical concurrent
  allowlisted reads coalesce within a session, without response caching. Ordinary
  reads have a 12-second overall deadline, mutations a 20-second default; explicit
  match/reward deadlines and same-command-ID retries remain intact.
  Uploads explicitly allow 40 seconds. No generic mutation retry was added.
  Late token acquisition cannot start a mutation after its deadline; responses
  from ended sessions are discarded. Malformed gateway bodies fail predictably.
- Startup warms current-theme artwork only, with two concurrent decodes and a
  four-second ceiling. Unused shop skins and remote music no longer block login.
  Remote skin paths use NetworkImage, not AssetImage. Lantern layout/art is unchanged.
- Edge version 37 is ACTIVE. Exact-origin preflights permit a ten-minute browser
  cache; authenticated replies remain no-store. Unchanged profile fields no longer
  rewrite the row's updated_at. All RTDB/SQL deletion guards and refusal triggers
  remain. Four independent social reads are now one indexed SQL statement with
  the same response shape and a single MVCC snapshot.
- SQL admission still permits only one active connection per isolate, with no
  idle pool. Queued work expires after five seconds without executing. Tests
  prove that an expired slot cannot bypass an active transaction or replay work.
- Privacy-safe Edge timings cover JWT, deletion guard, queue, connection, work,
  profile sync, social query, commit, mirror and close. Labels are allowlisted;
  no UID, room ID, request body, private cards, tokens or credentials are logged.
  db_work includes nested stages: do not sum overlapping durations as a total.
  Client profile/debug builds report token/HTTP durations without private values.

Verification:

- Flutter full suite: 376 passed; server/page suite: 158 passed.
- Flutter analysis: zero errors (existing warning/info backlog remains).
- Complete Edge entrypoint: Deno check passed. Release web build passed.
- Production read-only EXPLAIN validates existing social indexes; a nonexistent
  actor test query returns the expected empty arrays/map without creating records.
- Production v37 smoke: health 200, allowed preflight 204 with max-age 600,
  unauthenticated POST 401, untrusted origin 403, response no-store.
- Local Firebase emulator rerun is incomplete: this Windows JRE fails its NIO
  loopback connection at startup, before any rule tests execute. Rules are
  unchanged; the Ubuntu deployment workflow must still pass that gate.

Still pending (not claimed fixed):

- Authenticated cold/warm latency comparison and actual region/pooler A/B checks.
  The isolated performance guest/private-room fixture needs separate approval.
- Consistent own-hand realtime revision feed, command-response reuse and duplicate
  revision suppression, durable monotonic publication/repair before early ack,
  and coalesced timed advances with failover.
- Actual pending-card feedback, accepted-event presentation decoupling, measured
  repaint/selectors, sized background decoding and fingerprinted artwork caching.
- Full Android/iOS CI result checks, physical-device/mobile-web profiling,
  packet-loss/reconnect/concurrency QA and final before/after targets. Tests and
  a successful web compile are not evidence that mobile frame/latency targets
  have already been reached.

No existing player, match or balance was used as a mutation test or reset.
No paid plan, region override, schema migration or access-rule relaxation was made.
Rollback: redeploy the compatible version-36 source from baseline commit
3f60ff9c and revert this first client batch if measurements show a regression.

## Implementation update — realtime/presentation batch

- Atomic RTDB `matchViews/<room>/<uid>` pairs the public board and only that
  human's hand with one server revision and recipient tag. Bots/departed seats
  have no view. Parent, opponent, spectator, admin-bypass and client-write
  access are denied; deletion tombstones and active membership remain required.
  Room deletion removes the tree. Account deletion inventories orphaned views
  and removes the deleted user's child, preserving peers' data.
- Client validates recipient, room, protocol, version and own hand count
  (including Firebase's omitted empty arrays). Healthy private feed updates
  require no per-revision HTTP read. A 500-ms grace handles listener ordering;
  missing/failed feeds use the existing authenticated snapshot endpoint.
  Accepted play/settlement responses are reused. Stale/equal revisions are
  suppressed, with one exception for initial same-version private hydration.
  Removal/deletion and stream cancellation invalidate pending reads.
- A selected card lifts immediately and displays a pending indicator until
  its actual request finishes. Tap/drag/queued actions share that real in-flight
  guard. It does not invent a capture, score or accepted turn. English and both
  Arabic locales include accessible pending feedback; hit geometry is unchanged.
- Timed advance/settlement requests prefer one connected human and stagger
  others by 1.5 seconds as fallback if no newer accepted revision arrives.
  Known disconnected primaries are bypassed. This is a client request hint,
  not authority: server deadlines, version checks and idempotency remain.
- Playing cards subscribe only to equipped card ID and catalogue changes, not
  unrelated purchases/table changes. Static Lantern backgrounds are isolated
  and quantized for bounded native decoding (up to 2048 px). No frame-rate
  benefit is claimed without a device/browser profile.
- Web build fingerprints 75 raster image variants by SHA-256 while preserving
  logical AssetImage keys and dpr metadata in both Flutter manifest formats.
  Only content-addressed artwork and already-hashed JS entrypoints get immutable
  cache headers. Originals, manifests, index and private replies still revalidate.
  The strict manifest codec fails closed if Flutter changes its encoding.

Verification before rollout: 388 Flutter tests passed; 161 server/build tests
passed; analysis has zero errors and the same 266 warning/info backlog. Complete
Edge Deno check and release web build passed. The real generated web manifest
round-tripped and 75 images were fingerprinted. Added tests cover callback
ordering, fallback, cancellation, stale responses, recipient/hand-count checks,
long pending requests, leave/dispose, coordination, Unicode/dpr/cache paths and
private-feed rules. Local RTDB-only emulator startup also hits the Windows Java
loopback error, before tests; Ubuntu CI must pass the new permission gate.
First-batch Hosting, Android and iOS CI are all successful.

Remaining: durable ordered publication/retry before early command acknowledgment,
authenticated region/pooler and before/after measurements, isolated live failure
and reconnect/concurrency QA (approval pending), and physical-device frame profiling.
This batch preserves the current serialized publication lock; it is not an
unverified early-ack change or a claim that every latency target is achieved.

## Implementation update — durable delivery and isolated QA (10 October UTC)

- Gameplay revisions and private SQL publication intents commit in one
  transaction. Queue records contain only a room ID/revision, never cards or
  credentials. A transaction-scoped advisory lease serializes publishers,
  deletion publication and admin room deletion. Each publisher reads the latest
  committed board and hands together, then removes only intents at or below
  that snapshot's revision. Normal compatible delivery still locks game rows.
- Early-ack mode commits before scheduling background delivery and returns the
  authenticated caller's own snapshot. Background tasks are not assumed durable:
  an independently authenticated, Vault-key retry worker drains eligible pending
  intents in bounded batches, with backoff. Idle queue means no HTTP invocation.
  No paid service or access-rule relaxation was introduced. RLS is intentionally
  deny-all for both private publication tables; the advisor's two no-policy INFO
  notices are expected. Client roles have no table/function grants.
- The migration initially pauses the scheduler using `cron.alter_job`, not a
  forbidden direct update of `cron.job`. Both migrations were applied, their
  local filenames aligned with verified production history, and Edge v42 is
  ACTIVE with the temporary cleanup adapter removed. Retry scheduling is active;
  global early acknowledgment remains OFF, and the QA canary is cleared.
- Joining/reconnecting reuses a complete own-hand accepted response. An older
  public membership revision cannot kick a newly joined player or replace a
  newer accepted revision. Actual same/newer removal and room deletion still
  invalidate reads immediately. Incomplete/foreign-hand seeds cannot bypass
  authenticated recovery. There is no optimistic score/turn/capture update.

Live QA was explicitly approved for exactly one new guest/private bot room:
`EJE77344`, guest `qbjS8MTi6Yd1YzDIob7PbZhuWjE3`. Global early ack stayed false;
only that room was temporarily selected by the private SQL canary configuration.
Six serial updateProfile commands per mode measured client round trips:

| Mode | Samples | Reported median | Sample p95 |
| --- | ---: | ---: | ---: |
| Compatible synchronous delivery | 6 | 1,868 ms | 1,949 ms |
| Isolated early-ack canary | 6 | 1,447 ms | 1,962 ms |

The sample uses sorted upper-middle/nearest-rank percentiles. Median decreased
about 23%, but this tiny sample does NOT establish a p95 benefit, tap-to-animation
timing, region/pooler improvement, or resolution of the whole-app lag.

- One real human turn accepted exactly one of two concurrent different-card
  commands; the other returned version_conflict. The hand lost one card only.
  Retrying the accepted command preserved appliedVersion and did not replay it.
- The authorized own-hand SSE feed delivered revision 21, only that guest's
  three-card hand, and the matching board. Closing/reopening the stream returned
  revision 21 again; reconnect took 474 ms. Bot preparation/capture phases used
  actual server deadlines, not rewritten clocks. No match was completed or paid.
- Teardown used a temporary authenticated adapter restricted to that exact UID,
  exact canary room, private visibility, sole human seat and one-hour creation
  window. It held the publication lease while removing only the six fixture
  RTDB roots and SQL room. The guest deleted its own Firebase identity, and a
  guarded SQL statement removed only its null-email QA profile. The adapter was
  immediately removed and clean source redeployed as v42. QA room/profile/intent
  counts are all zero; totals returned to the pre-QA 23 profiles and 27 rooms.
  No existing player, match, wallet or balance was deliberately mutated.

Verification: 394 Flutter tests and 171 server/build tests passed; Deno check and
release web compilation passed; analysis has zero errors (267 warning/info
items remain). The real Flutter AssetImage/AssetManifest SDK test resolves the
fingerprinted retina image with preserved scale. Previous batch Hosting, Android
and iOS CI all passed, including Ubuntu private-feed permission tests. Latest
delivery-batch CI/deployment must also pass before any broader early-ack rollout.

Still outstanding, not marked complete:

- Broader early-ack activation and tail/failure testing: ambiguous transport
  completion, worker termination, dropped packets and reconnect while commands
  compete need a larger controlled run; the current live test is not that test.
- Authenticated routing/shared-transaction-pooler A/B measurement. No region
  override or database credential/connection change was made without evidence.
  The unified-log service returned a backend error during the stage-timing read;
  it was not repeatedly polled or treated as an empty-success result.
- Browser/physical-device rendering profile and end-to-end latency targets for
  lobby, store, social screens and online play. Desktop inspection is not proof
  of smooth iPhone/Android rendering, and an offline widget test is not online QA.

Desktop observation: an authenticated production homepage reload captured in
Edge's Performance panel spans 7,518 ms, with 2,670 ms scripting, 831 ms system,
27 ms rendering and 8 ms painting. Bottom-up lists 466.7 ms profiling overhead
and 336.0 ms script compilation. LCP/INP are unavailable in this load-only trace;
CLS is zero. Existing extensions and docked DevTools make this a diagnostic
sample, not an extension-free benchmark or a mobile frame-rate measurement.
No match, purchase, account setting or balance was changed during this trace;
DevTools was closed afterward. Startup scripting remains a profiling lead, not
proof of the cause of ongoing online latency.

Rollback: keep global async_ack_enabled false, clear canary_room_id, and pause
only the publication cron job if needed. Compatible delivery and authenticated
snapshot recovery remain. Preserve private tables/deletion tombstones rather
than dropping safety data or replaying queued game commands.

## Implementation update — guarded connection overlap and recovery

The log service recovered. A narrow read of 21:25–21:34 UTC on 10 October
returned two getSocialGraph and two getAdminStatus timing events. Totals were
798–900 ms; deletion_guard was 354–377 ms and db_connect 245–280 ms, with
db_queue zero. These are four recent server executions, not a controlled
before/after sample or client end-to-end measurements.

- After Firebase JWT verification, normal SQL-backed calls now start the
  independent deletion-block read and bounded connection setup together.
  The application callback cannot query, bootstrap, read data or mutate until
  the block read succeeds. The durable SQL deletion-job check and profile
  recreation trigger remain. Both promises are observed; guard denial takes
  precedence even if connection setup fails first, and the runner closes the
  socket without replay. Firestore-only discovery still awaits its guard and
  never opens a SQL connection. Receipt/deletion-worker authorization is
  unchanged. Connection admission, no-idle policy and transaction ownership
  are unchanged. No guard result is cached. Overlapping timing stages must
  not be summed as independent serial durations.
- A failed or lagging authenticated snapshot recovery no longer relies solely
  on another heartbeat. It gets at most three automatic retries with 1/2/4-second
  backoff for an unchanged revision. Success, kick, room deletion and disposal
  cancel scheduled retries. New revisions retain coalescing and stale/private
  view validation. This retries reads only, not play, purchase or reward commands.
  Persistent outages exhaust the budget rather than spinning indefinitely.

Verification: 399 Flutter tests, 174 server/build tests and complete Edge Deno
type-checking passed. Analysis has zero errors and 263 warning/info items;
modified stream/test flow-control lint was cleaned up. Edge version 43 is ACTIVE
with the guarded-connection implementation. Prior commit dbc90694 Hosting and
Android workflows passed; its iOS workflow was still compiling at this check.
The next client release must pass its own CI/deployment gates.

No additional live guest, room, purchase, reward or account-deletion fixture
was created. The consumed one-fixture approval is not reused. Global early ack
stays off; actual latency improvements from connection overlap, region/pooler
A/B, transport-failure rollout and physical-device profiling remain unverified.
Rollback for this batch: redeploy the version-42 backend source and revert
only the guarded-connection/recovery commit; preserve the publication queue,
private views and deletion guards.
