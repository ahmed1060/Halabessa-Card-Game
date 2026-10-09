# Account deletion verification — 9 October 2026

## Scope and rollout

The publisher approved production activation after local verification and an
isolated temporary guest/private room test. Existing players, balances and shared
matches must be preserved. No global user reset is authorized.

Supabase project jmlipglfgmuyegoroepu has halabessa-api version 36 active. It
uses verified Firebase JWTs for consumer requests; platform Supabase JWT checking
remains disabled intentionally because these are Firebase credentials. The
worker requires its separate private Vault key and clients cannot read deletion
tables. Receipt-only status cannot authenticate a player or select a target UID.

The client changes are delivered in the commit containing this report. Hosting,
Android and iOS CI must pass for that commit before claiming client rollout.
The prior ff4bfe4e commit passed all three workflows; the iOS artifact is unsigned,
not a TestFlight/App Store installable release.

## Implementation

- Acceptance verifies the live identity, confirmation and recent authentication,
  protects publisher/admin accounts, and commits an idempotent job before any
  identity revocation. A credentialless guest uses a freshly issued ID token;
  linked guests cannot bypass actual provider reauthentication.
- Apple-linked identities wait for verified revocation. Provider secrets are
  neither logged nor persisted. The scheduler excludes unrevoked Apple jobs.
- The minute Cron worker retries without a user session, leases via transaction
  row locks, processes bounded work and closes its database connection. It makes
  no Edge/network calls when the eligible queue is empty.
- Ordered stages block sessions, release/anonymize rooms, remove social/message
  attribution, remove profiles/reservations, remove owned avatar objects, then
  delete identity. Failure never advances completion. Temporary inventory is
  removed only when no retry needs it.
- Frozen rewards settle before room anonymization. Room locks/outbox delivery
  preserve other seats, cards, scores and duplicate command protection. Semantic
  identity fields are scrubbed; arbitrary text/card substrings are not replaced.
- Peer lists are server-derived and persisted before removing the canonical
  association. Per-field conditional updates preserve other player data. Legacy
  attributable room state requiring reconciliation remains pending for review.
- Avatar cleanup uses the Storage API, not SQL-only metadata deletion, and waits
  for admitted uploads to drain. Shared publisher assets are never removed.
- The Lantern-themed UI requires deliberate confirmation, supports guests,
  reauthenticates without changing UID, saves a random receipt before submission,
  and resumes status after a restart or lost response. Pending is not Complete.
- Public English/Arabic notices describe the actual flow and retained records.
  User-ID tombstones/job records, de-identified reward receipts and service logs/
  backups are not falsely described as immediately erased or fully anonymous.

## Live evidence

The one approved temporary guest had a private, one-human lobby, zero balances,
owned profile/username/presence and a tiny owned avatar. No public match, real
player balance or authored chat message was seeded or modified for this test.

The original guest session was lost across the resumed task. A strictly scoped
trusted SQL insert queued its job after checking the exact guest/room ownership,
zero balances, no email and no admin flag. This exercised the real production
worker, **not** normal authenticated HTTP acceptance or provider reauthentication.
A replacement guest requires separate approval and has not been created.

Live execution found Firebase HTTP 400 on shallow inventory queries: the wrapper
sent X-Firebase-ETag with query parameters. The adapter now requests ETags only
for unfiltered compare-and-set reads. The same job advanced after deployment,
confirming the cause. Historical safe RTDB keys and five-room bounded batches
were also covered so unrelated old room records do not strand the queue.

The job completed all six stages at 10:22 UTC. It checked 60 peer records and
157 room records. Live receipt recovery returned Complete. Verification found
the Auth identity, Firestore profile/username, RTDB profile/presence and avatar
object absent, with no remaining cleanup inventory or delivery outbox.

An expiring, worker-key-gated action restricted to this exact completed test job
and empty expired private room removed its room mirrors and SQL room/anonymous
owner stub. It was immediately removed; Edge version 36 is the stable source,
with no temporary cleanup action or arbitrary-account deletion endpoint.

Final production counts returned to the original 22 shadow profiles and 27 rooms.
The existing profile/wallet fingerprint matched the baseline exactly. No pending
jobs remain. The completed job and Firebase security tombstones are intentionally
retained to prevent old sessions/profile recreation. The deleted QA account and
test data cannot be restored by this feature; existing player data was preserved.

All 13 migration sources match the applied SQL after accounting for whitespace/
comments. Filenames were aligned with actual Supabase timestamps. No schema
migration was replayed and the remote migration history was not repaired/rewritten.

## Automated verification

- Full Flutter suite: 363 passed; final focused receipt/confirmation/recovery
  suite: 15 passed, including explicit guest consent and pending Back protection.
- Full server/page suite: 155 passed, including bounded cleanup, outages,
  timestamp fairness, ETag/query behavior, legacy-key and receipt recovery tests.
- Firebase emulator rules: 24 passed, including retained-token access refusal,
  unrelated-user access and private-team chat. No old live QA token was available,
  so retained-token denial is an emulator proof, not a live-token assertion.
- Changed Flutter files: analyze cleanly. Complete Edge Deno entrypoint: checked.
- Release JavaScript web build: successful. Optional existing Wasm plugin
  warnings are not a claim of Wasm or native/hardware acceptance.
- Supabase security advisors: no findings at the final check.

## Remaining acceptance gates

1. One newly approved isolated guest can prove normal authenticated HTTP
   submission, duplicate submission and live old-token refusal. The current
   worker test must not be represented as that end-to-end acceptance.
2. Fresh browser interaction/visual QA stopped when computer-use could not
   verify the browser URL safely. No further UI input was sent; automated widget
   fixtures are not a substitute for deployed interaction acceptance.
3. Publisher-configured Google/Facebook/Apple live authentication, cancellation,
   conflicts and Apple revocation require provider accounts and native devices.
4. Physical iPhone/Android touch, safe areas, rotation, background recovery,
   accessibility, signing and signed store artifacts require publisher acceptance.
5. Store privacy/Data Safety/age declarations and regional legal review remain
   publisher release gates. Current audience is 13+ in Egypt, Saudi Arabia, USA
   and Canada; this report is engineering evidence, not legal/store certification.
