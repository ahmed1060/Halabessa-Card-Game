# Server-controlled room rollout — 5 October 2026

Live activation gates passed; the creation-policy change was pushed as 223262d5. New online rooms will
request protocol 1 by default. Existing rooms retain their saved protocol, and
offline training remains local. An emergency rebuild can set
`HALABESSA_SERVER_MATCHES=false`; this affects new rooms only, not active rooms.

Verified for this checkpoint:

- 292 Flutter tests and 88 backend tests passed after the recovery fixes.
- Rollout-default and explicit rollback-flag tests passed.
- Static analysis has no errors (247 existing warning/info notices).
- Hosting run 37297052965 passed isolated Firestore/RTDB permission tests and
  deployed the rules. Local emulators fail in Windows Java loopback initialization;
  no permission rules were weakened to work around that environment issue.
- Supabase security advisors returned no findings.
- Private protocol-1 UI fixture KTD16855 continued through rounds 3 and 4,
  successive deals, manual moves, bot moves, captures, and scoring.
- Browser reload restored the same room, scores and own private hand, and play
  continued afterward.
- Human Yes shuffle recorded matching bot Yes ballots, advanced one round, and
  rotated the dealer once.
- Full match reached results at 14–22, displayed rewards and replay controls.
  Server settlement completed with a reward receipt and settlementPending=false.
- The ten-second rematch window expired; the unanswered human became No and
  the match closed with scores intact. No successful live replay is claimed.
- The approved one-time reopening of KTD16855 was performed; reload exceeded
  the ten-second deadline, so that attempt also expired. It was not reopened again.
- Public fixture QFP39484 exposed an unattended-room deadlock: the last human
  left on their active turn, leaving no participant able to advance the bot.
  Revision 25 permits an explicitly released active seat to be claimed only
  when all four occupants are bots, under the existing transaction lock. It
  renews the incoming human's turn deadline and preserves hand/team/score.
- Live code-based rejoining succeeded with the preserved hand and score.
  Lobby joining exposed a second race: disappearance of the availability tile
  disposed its context before navigation. Route-level navigation handles now
  survive that removal; a widget regression test verifies this sequence.
- A subsequent live leave and lobby-button join opened /game successfully,
  restoring the same seat, remaining hand, round 2 and score 1–5.
- Best-effort presence operations now handle permission failures after server
  membership revocation without producing unhandled asynchronous exceptions.
- Previous Hosting, Android and iOS runs for 39612c9d all completed successfully.
- Recovery fixes were pushed as 7b70897e; Hosting run 37308599832 succeeded.
  Android 37308599816 and iOS 37308599775 were still running at the last check.
- Supabase revision 25 was read back and all 13 deployed files matched the
  local deployment payload. Security advisors returned no findings afterward.
- User approved lowering only QFP39484's target from 21 to 7 to finish the
  live test. Scores stayed intact. Normal gameplay reached results at 12–6;
  the human's Yes replay vote was accepted within the ten-second window.
  The same room reset both scores to zero, advanced matchSequence to 1 and
  dealt a new round. The QA target was then restored to 21.
- Final review extended unattended recovery to pre-round cut, deal and capture
  phases, preserving their existing phase. Scoring, voting and results remain
  excluded to protect the settlement roster. Eight targeted Flutter tests and
  all 89 backend tests passed; this backend is deployed as revision 26.

Remaining activation gates:

1. Publish the creation-policy change and verify deployment plus normal room
   creation (without the QA build flag).

No user accounts, balances, or non-QA match data were reset or deleted.
