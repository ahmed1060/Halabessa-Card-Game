# Remaining features — approved 7 October 2026

The user approved all previously deferred features. Preserve the lantern-café UI,
existing player data, free hosting and authoritative game rules. Implementation
must not be confused with production rollout or physical-device acceptance.

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
Account deletion, child-account safeguards, final legal publication, production
rollout and physical/native acceptance remain unfinished. No mass user reset is
part of this work. Keep the requested single final push until the batch is ready.

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
