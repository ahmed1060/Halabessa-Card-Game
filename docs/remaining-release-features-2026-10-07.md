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
