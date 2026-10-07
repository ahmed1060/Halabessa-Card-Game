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

The audience includes children; first markets are Egypt, Saudi Arabia, USA and
Canada. Under-13 inclusion remains unanswered. Public legal pages must not be
published as an adult-only policy. See account-data-release-review-2026-10-07.md
for the actual data inventory, deletion safety contract and child-release gates.
Account deletion, child-account safeguards, final legal publication, production
rollout and physical/native acceptance remain unfinished. No mass user reset is
part of this work. Keep the requested single final push until the batch is ready.
