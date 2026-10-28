# LAN qualification and portable release preparation

Work locally on development. The scoped Unity LAN adapter and fresh Android,
iOS and WebGL exports already pass the previous review. The shipping export
directories still contain older players; do not treat the QA APK as a release.

## Protected boundary

No game rules, host authority, timers, card counts, scoring, bot decisions,
voting, sound selections, motion durations or production flags will change.
No push, merge, deployment or device installation is part of this batch.
Unity remains a presentation consumer; LAN commands and private snapshots retain
their current identities, revision ordering, retry and reconnect behavior.

## File map and acceptance

- Add test/lan_full_match_test.dart: actual LanMatchDriver and loopback pinned
  TLS clients, complete Classic and Tafweet matches, three hands per deck,
  card conservation, per-player reveal/slam limits and resets, peer resume,
  shuffle/rematch votes, private views and zero cloud economy/Firebase use.
  Use real production timers and no authority injection or accelerated clock.
- Add tool/prepare_unity_release.mjs and its Node tests: validate successful
  isolated export reports, capability markers and hashes; stage portable player
  payloads into a new ignored build directory, retaining existing integration
  files separately and documenting mismatches rather than overwriting them.
  A manifest must distinguish verified export payloads from shipping paths.
- Add qualification results to this document or a paired review document.
  Existing game, bridge, renderer, workflows, native project integration and
  shipping binary paths are inspected but will not be modified in this batch.

There is no new visual beat sheet: windup/contact/settle, easing, reduced motion,
Flutter audio/haptic ownership and snapshot catch-up are unchanged. The existing
3D setting restores Flutter presentation. Rollback for this batch is removing
the new qualification/tool files; all staged players remain ignored and the
previous shipping export is preserved. Physical Wi-Fi, native compositing,
permissions, haptics and Xcode compilation remain separate acceptance gates.
