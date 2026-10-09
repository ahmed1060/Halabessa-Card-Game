# Remaining features — approved 7 October 2026

The user approved all previously deferred features. Preserve the lantern-café UI,
existing player data, free hosting and authoritative game rules. Implementation
must not be confused with production rollout or physical-device acceptance.

## Current status — latest verified state

The historical batches below describe their status when written. They are not
the current deployment status. Hosting 37619230171, Android 37619230099 and iOS
37619230105 all succeeded for ff4bfe4e. The granted Datastore Index Admin role
resolved the index-deployment blocker; the logout fix, profile privacy rules,
age gate, release notices and earlier feature work are deployed.

The authenticated self-deletion endpoint, receipt-only status recovery and
independent scheduled worker are now active in Supabase Edge version 36. The
approved isolated QA job completed all six stages; its Firebase identity,
profiles, username, avatar, presence and private room were removed. Existing
player profiles and balances remained unchanged. Only disclosed deletion/security
records were retained. No mass reset or deletion occurred.

This batch includes the Lantern-themed confirmation/recovery UI, provider
reauthentication and Apple revocation integration, public notices and CI gates.
Its client rollout is subject to the Hosting workflow for the containing commit.
The live QA job was accepted through exact-target trusted SQL because the original
guest session was lost on resume: this proves the production worker, not the
normal authenticated HTTP submission or native provider flow. A replacement
live guest test awaits separate approval. Fresh interactive UI acceptance is
blocked by the computer-use browser URL safety check; physical device, provider,
signing, legal/store declarations and publisher acceptance remain release gates.
See account-deletion-verification-2026-10-09.md for the evidence and limitations.

## Confirmed decisions

- Publisher: WeirdPuzz; public contact: weirdpuzz@gmail.com.
- Public chat: current-match participants, not a global lobby.
- Team chat: private to current teammates, enforced on the server.
- Game channel: read-only authoritative events.
- No mass user deletion or balance reset is authorized by this feature work.

## Sequence and acceptance

1. Apple guest linking: use Firebase provider linking on native iOS and popup
   linking on web; preserve UID, propagate credential conflicts, guard simultaneous
   provider submissions. Native Apple configuration/device verification remains.
2. Support: public contact page and in-app contact information. Privacy/legal
   publication requires an accurate inventory of processed data and retention,
   not template claims. Draft against actual Firebase/Supabase behavior.
3. Round accounting: record public per-round score components at authoritative
   transitions, including capture points and final majority award. Test ties,
   Tafweet, round resets, offline parity and total consistency before displaying.
4. Weekly ranking: UTC Monday-to-Monday period, derived from exactly-once match
   settlement. Preserve existing all-time ranking and never seed the week from
   cumulative balances. Test duplicate settlement and period boundary.
5. Presence filters: authenticated heartbeat/disconnect lifecycle, stale status
   explicitly offline; filters reflect fresh server observations. Avoid global
   per-user polling or unnecessary free-tier connections.
6. Chat: distinct public/team storage and membership authorization. Existing
   `matches/$matchId` reads are inherited by descendants, so team messages must
   never be placed there. Recheck team membership after replacement/replay;
   spectators cannot read private team messages. Test opponents, outsiders,
   former occupants, spoofed senders, size/rate limits and read-only events.
7. Account deletion: reauthentication, deliberate confirmation, idempotent
   server job, revoke/disable identity before cleanup, remove private profile,
   social edges, usernames, inventory and attributable data across both services.
   Preserve anonymized shared match integrity where needed and disclose actual
   retention. Protect admin privileges and never accept an arbitrary target UID.
   Do not perform live deletion without separate exact-target authorization.
8. Finish: complete regressions, emulator access-control tests, build all targets,
   deploy backend before dependent clients and compare against approved mockups.
   Physical iPhone/Android touch, rotation and provider checks require hardware.

## First implementation batch

- Apple sign-in now links guests rather than replacing their account, native and
  web. Profile exposes Apple linking on iOS/web with existing pending/error guard.
- Ten focused auth/widget tests passed, including native guest conflicts and
  simultaneous-provider protection. This does not establish live Apple success.
- Added public support page and in-app publisher/email with copy action.
- Other features above remain in progress, not implemented by this batch.

## Second implementation batch (local; not yet pushed or deployed)

- Per-capture awarded points now travel with server/offline capture history.
  Completed-round UI shows capture points, Tafweet bonus, majority bonus and
  this-round total. Legacy/incomplete awards are hidden rather than guessed.
- Weekly standings are recorded in the same conditional Firestore commit as
  the exactly-once reward receipt. UTC Monday boundaries and late settlement
  are tested. Three indexes and deployment configuration are prepared.
- Rankings no longer substitute fictional players on query failure or append
  a non-top-50 player as though their global rank were 51. Retry UI is explicit.
- Online/offline friend filters use per-connection heartbeat/disconnect presence,
  expire stale status, and keep the presence session across route changes.
- Match-only Public/private Team storage is separate from broadly readable match
  state. Read/write rules verify present seat membership, sender, timestamps and
  rate limits. Game events are read-only. Legacy rooms retain public chat only;
  offline training does not pretend to send multiplayer messages.
- Nineteen Firebase emulator access-control tests passed, including private chat
  and weekly-ranking forgery protection. Emulator processes shut down cleanly.
- Full Flutter regression suite: 334 tests passed. Full CI server/settlement/web
  startup suite: 92 tests passed. Final release web build succeeded. Analysis
  reported no errors; existing informational lint/deprecation notices remain.
- Five ranking widget tests and eight round-summary layout tests cover period
  values, query failure, portrait/landscape, RTL/LTR and enlarged score-panel text.
  These are isolated fixtures, not a claim of production or physical-device QA.

## Newly confirmed release scope

The user subsequently confirmed ages 13+ only for the current release; first
markets are Egypt, Saudi Arabia, USA and Canada. Under-13 access is out of scope.
A device-local eligibility gate checks the full birthday before sign-in and
stores only eligibility, not the birth date. This is self-declaration, not verified
identity or proof of legal compliance. See account-data-release-review-2026-10-07.md
for the actual data inventory, deletion safety contract and child-release gates.
At the time of that audience decision, account deletion, public notices and
rollout were unfinished. Their latest state is described at the top of this
document. The current 13+ scope does not authorize an under-13 rollout; physical,
native and publisher/legal acceptance remains separate from implementation.

## Third implementation batch (local; not yet pushed or deployed)

- Added a 13+ eligibility gate before the auth stream, account routes, presence
  and game overlay mount. Full birthday boundaries, future dates, persisted
  refusal, concurrent submissions and blocked layouts are tested. It stores only
  eligibility, never the date of birth. This is not identity-based age verification.
- Private Firestore/RTDB profiles are owner/admin-readable only. Public profile
  previews, rankings and friend search use the server's scalar allowlist. These
  Firestore-only requests do not open a Postgres connection.
- All 341 Flutter tests passed, including seven age-gate tests; all 21 Firebase
  emulator tests passed. Four profile projection tests passed. Analysis has no
  errors; existing warnings/informational notices remain.
- The full CI server suite passed all 96 tests and the release web build succeeded.
  Its optional Wasm dry run reports existing plugin incompatibilities; the shipped
  JavaScript web target builds successfully. Native targets were not built here.
- Account deletion, public policy/terms publication, production rollout and
  physical/native verification still remain. No live deletion or user reset ran.

## Rollout and fourth batch — 7 October 2026

- Commits through 91717f17 were pushed to main. Supabase Edge version 27 was
  deployed first, with the profile projection and weekly scoring dependencies.
  Live health returned 200 and an unauthenticated profile query returned 401.
- Hosting run 37598005302 passed server tests, 21 emulator tests, analysis and
  all 341 Flutter tests. Deployment stopped with HTTP 403 while listing Firestore
  indexes. The GitHub deployment principal needs roles/datastore.indexAdmin;
  no IAM permissions were silently granted or failed gates bypassed. Hosting
  did not update in this run. Indexes now deploy before dependent rules.
- Prepared public privacy/rules-of-use pages in English and Arabic, matching the
  same JSON text bundled in native screens. Notices are readable before sign-in.
  A public account-deletion page describes the current publisher-email request
  route honestly; it does not claim automatic in-app deletion exists.
- Four web-page consistency/link tests and four unauthenticated native-notice
  layout tests passed. The notices follow the approved lantern-café palette.
- Six deletion execution-contract tests passed: self-only and recent-auth
  authorization, protected admin identity, confirmed guest handling, durable
  acceptance before revocation, bounded restartable stages, failure handling and
  serialized workers. This module is not wired to an HTTP action: production
  storage/lease/cleanup adapters and in-app confirmation are still required.
- The updated complete Flutter suite passed all 345 tests; release web build
  succeeded with the notices bundled. No physical-device validation is implied.
- Automatic deletion and its live isolated QA test remain unfinished. Physical
  device checks and signed-store/provider configuration still require the
  publisher's devices and accounts; neither store acceptance nor legal review is
  implied by these engineering tests.

## Fifth batch — identity adapter and deployment diagnosis

- Added a server-only Firebase Identity Toolkit adapter with scoped one-UID
  lookup, minimized live identity data, disabled/revoked-session validation,
  disable-and-revoke and idempotent identity removal. Linked credentials are
  checked against the live account, not stale anonymous-provider token claims.
- Eight adapter tests plus six deletion-contract tests passed. These use mocked
  HTTP transport; no production user was disabled, revoked or deleted.
- The adapter is not wired into the Edge endpoint. Before activation it needs
  an OAuth token with the identitytoolkit scope and the existing service
  account's corresponding Auth permissions. Its active-session helper must be
  integrated with the durable deletion guard; adding this module alone does not
  change current JWT acceptance.
- Production deletion still needs private durable jobs/cross-worker locking,
  receipt-based retry after revocation, room/reward/social/avatar cleanup,
  old-token guards in both Firebase and Edge, native reauthentication/Apple
  revocation, confirmation/status UI, and the approved isolated live QA.
- Hosting run 37600507043 again failed specifically on Firestore index IAM
  permission after passing its tests. Android run 37600506984 succeeded; iOS
  run 37600506987 was still running at this check. Instructions for the narrow
  index-role fix are in manual-hosting-deploy.md. No permission gate was bypassed.

## Reported logout permission screen

- Found `userChanges().asyncExpand(...)` subscribing to an endless Firestore
  profile stream. `asyncExpand` pauses the auth source while its inner stream is
  active, so sign-out/account-switch events can be held behind the old profile
  listener; the listener then fails permission checks when Firebase signs out.
- Replaced it with a cancellable, generation-guarded session/profile switch.
  Auth changes are not blocked by profile enrichment, and obsolete profile
  results/errors cannot overwrite the signed-out or new-account state.
- Logout now awaits Firebase sign-out, reports an actual sign-out failure without
  abandoning the current route, and clears all authenticated routes on success.
- Three stream regression tests cover endless profiles, pending asynchronous
  enrichment, late permission errors, account switches and listener disposal.
  Seven existing social-auth regression tests also passed. Live-site verification
  still depends on unblocking Hosting deployment; this is not a deployed fix yet.
- Complete regression run after the logout fix: 348 Flutter tests and 114
  server/page tests passed. Analysis reported no errors; the existing 261
  warnings/informational lint notices remain.
- Release JavaScript web build succeeded. Optional Wasm dry-run warnings from
  existing web plugins do not imply a successful Wasm target or physical QA.

## Permission repair and durable deletion groundwork

- The publisher confirmed granting the deployment principal the index role.
  Retried Hosting run 37602418217: it successfully deployed indexes, dependent
  rules and Hosting for 35752df4. Android 37602418220 and iOS 37602418243 also
  succeeded. The logout fix is now deployed; an interactive logout check is
  still required rather than inferred from the build outcome.
- Added private account_deletion_jobs storage, deployed its migration and
  explicit deny-all client policy. Database constraints enforce ordered stage
  prefixes and completion only after all six stages. Recovery receipts are
  SHA-256 digests, not plaintext secrets. Queue rows survive account removal.
- A real Postgres row-lock adapter serializes bounded work across workers and
  supports transaction pooling. Six adapter tests use a simulated query layer;
  they do not establish live multi-connection deletion behavior.
- Added Firebase server-only deletion-block rules and Edge checks before both
  discovery and ordinary SQL work. Ordinary API calls cannot recreate a profile
  while its durable deletion job exists. Twenty-three isolated emulator tests
  passed, including retained-token refusal and unrelated-player access.
- Edge revision 28 deployed successfully with these guards. There are zero
  deletion jobs; no player identity was disabled/deleted and no live QA guest was
  created. The new Firebase guards are pending this batch's Hosting deployment.
- All 122 server/page tests passed. Account deletion remains unavailable: room,
  reward, social, profile and avatar cleanup adapters; authenticated acceptance
  and receipt/worker endpoints; scheduled recovery; native confirmation,
  reauthentication/Apple revocation; and the approved isolated live QA are still
  required. The private queue is not an operational deletion feature by itself.
- Added the room-state anonymization step: normal leave/bot takeover preserves
  other seats, cards and scores; historical UID references and attributed names
  are scrubbed. It refuses pending rewards or legacy snapshots rather than
  silently changing settlement eligibility. Three focused tests passed; the
  complete server/page suite now has 125 passing tests. SQL ownership transfer,
  mirror delivery and legacy cleanup still need integration.
- Live browser verification could not run: the browser tool failed twice during
  initialization with a missing kernel-assets path. No browser interaction or
  new guest creation occurred. Existing G1 mockup/local screenshot comparison
  is not a substitute for a fresh deployed visual/interaction check.

## Targeted cleanup adapters and profile-recreation guard

- Added a private invoker trigger preventing ALL shadow-profile insert/update
  paths from recreating an account with a pending/completed deletion job. This
  includes another player's social/invite request, not only the deleting caller.
  Applied its migration and verified update/recreation refusal in a rollback-only
  live SQL test. Both temporary QA rows and the temporary job were rolled back;
  post-test counts were zero. No real Firebase account was involved.
- Added bounded Firestore social-field transforms, conditional username cleanup
  and owner-profile removal. Update-time preconditions preserve reassigned names
  and changed peers; absence is idempotent, denied/conflicting writes stay pending.
- Added Storage API cleanup for all six historically allowed owned avatar
  variants, including audio accidentally permitted by the old upload endpoint.
  New avatar uploads reject audio MIME types and ambiguous sanitized UID paths.
  No bucket-wide delete or metadata-only SQL deletion occurs. Ambiguous legacy
  sanitized/truncated UID paths fail closed for manual ownership review. Removing
  origin objects does not promise immediate expiry of browser/CDN caches.
- Added RTDB cleanup of own mirrors/presence, per-field ETag social removals,
  bounded authored-message removal across public/team/legacy channels and chat
  indexes. Tests verify that indexes do not bypass private-team authorization.
  These adapters need a complete server-derived peer/room inventory at integration;
  consumer-supplied target lists must never authorize cleanup.
- Added a private room-delivery outbox and a leased SQL room adapter. Frozen
  rewards settle before anonymization; leave/bot takeover preserves cards/teams;
  SQL ownership transfers to a surviving player or a non-Auth anonymous stub.
  SQL changes and delivery intent persist together. A later pass publishes the
  latest committed room under its lock, so failed delivery can resume without
  repeating takeover or publishing uncommitted/stale state. Peer command IDs
  remain valid while their redundant cached snapshots/private hands are removed.
  Unsupported legacy matches remain pending rather than being erased.
- Corrected anonymization to operate on schema-defined identity fields only.
  Custom UIDs matching a card rank or another player's name do not corrupt them.
- Current local verification: 148 server/page tests, 24 isolated Firebase rule
  tests; deletion adapter TypeScript checking is now a CI gate. Room adapter
  tests use an injected query layer, not a live end-to-end deletion claim.
  Security advisors reported no findings; both private deletion tables have RLS
  enabled with no client read grants. Queue/outbox counts remain zero.
- None of these cleanup adapters is exposed as an active deletion endpoint yet.
  Production cleanup execution, scheduled recovery, client flow and approved
  end-to-end deletion QA still need completion. No existing player was deleted.
- Edge revision 29 is active with the upload-policy fix and safe unavailable-
  account response. Live health returned 200; unauthenticated bootstrap returned
  401. The new SQL profile guard/outbox migrations are deployed, with zero jobs,
  zero outbox rows and zero remaining rollback-test profiles. Firebase chat
  indexes are included in this batch's next Hosting deployment.

## Integrated deletion batch — 9 October 2026

- Durable authenticated acceptance derives its target only from the verified
  Firebase user. Explicit confirmation and recent authentication are required;
  the live credentialless-guest exception requires a freshly issued token.
  Primary publisher/admin accounts cannot be removed by the consumer flow.
- Linked Apple accounts require verified provider revocation before the worker
  can proceed. Provider credentials are not persisted. Failed revocation is
  recoverable and never presented as completed deletion.
- A private Vault-backed Cron worker resumes one leased job/stage at a time.
  Idle queues and requests awaiting Apple authorization make no Edge calls.
  Normal bounded progress rotates the queue fairly without a false failure.
- Peer/room/chat inventory is durable and server-derived. Cleanup preserves
  peer fields, anonymizes authoritative shared matches and settles frozen rewards
  before removal. Unsupported attributable legacy state fails closed for review.
- Diagnosed a real live blocker: Firebase rejected shallow/query reads carrying
  the ETag request header. Only unfiltered compare-and-set reads now request it.
  Historical room keys are validated separately from current room codes. Batches
  process up to five rooms per call rather than one room per minute.
- The UI saves a random status-only receipt before submission, keeps it across
  ambiguous network failures/restarts, distinguishes Pending from Complete and
  supports guests. It reuses Lantern café components; RTL/portrait/landscape
  fixtures and explicit confirmation/back-navigation behavior are tested.
- Local verification: 363 Flutter tests, 155 server/page tests and 24 Firebase
  emulator tests passed. Focused deletion tests passed after the final UI copy
  change; changed Flutter files analyze cleanly, the full Deno entrypoint checks
  and the release JavaScript web build succeeds. Security advisors found no
  findings. This is not physical-device or signed-store acceptance.
- The approved QA worker inspected 60 peer records and 157 room records. All
  six stages completed, status recovery returned Complete, and an admin lookup
  confirmed the Firebase identity was absent. A temporary private exact-target
  cleanup action removed only the empty QA room/stub, then was removed immediately.
  Production returned to 22 profiles and 27 rooms, with an unchanged existing-
  profile/balance fingerprint, no pending jobs, and no cleanup inventory/outbox.
- All 13 migration SQL sources were compared with applied history (differences
  only formatting/comments). Filenames now use the actual applied timestamps;
  no migration was replayed and no remote history was edited.
