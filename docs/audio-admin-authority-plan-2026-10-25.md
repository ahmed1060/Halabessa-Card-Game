# Audio settings authorization repair

## Baseline and authorization

The user approved fixing the live mismatch and completing the sound-manager
save/restore checks. Active checkout: build/lantern-remote-final; base main
48137b9d; branch codex/audio-admin-authority. Existing unrelated dirty analyzer,
Gradle and generated platform files are excluded and preserved.

The real upload produced an exact 30,032-byte copy of the chosen capture WAV in
Supabase Storage, but the subsequent direct Firestore setting write returned
permission-denied. Supabase's verified admin role and Firebase custom-claim
authorization are separate paths. No token was extracted to inspect its claims.

## Protected boundaries and outcome

Use the current authenticated Supabase admin admission for the audio settings
operation, then a narrow server-only Firestore adapter. Do not grant new roles,
modify custom claims, loosen Firestore rules, change database schema or migrate
settings. Authenticated Firestore listeners and existing document IDs stay.
Only the 16 existing sound/music slots and their saved-backup documents may be
written. No arbitrary URL, document path, metadata or account target is accepted.

Rules, hands, scoring, timers, votes, bots, Unity exports, bridge, playback timing,
selected audio bytes, mute/haptic ownership and the new chat mockups are out of
scope. There is no animation beat change: preview/upload/save/restore use current
UI and audio ownership; no renderer handshake or visual acknowledgement changes.

## Exact file-touch map

- New supabase/functions/halabessa-api/audio_settings.ts: strict operations/slot
  validation, server admission helper, immutable same-slot Storage URL checks,
  Firestore reads/writes and transactional committed-source save/restore.
- Small index.ts route addition: existing Firebase JWT/deletion guards, verified
  role and fresh active identity; release the Postgres connection before REST I/O.
- New lib/core/services/backend_audio_override_store.dart: implement the existing
  store interface through authenticated backend commands, never credentials or
  direct privileged Firestore writes in the client.
- global_settings_provider.dart: switch only its default audio write adapter.
- New edge_audio_settings.test.ts and backend_audio_override_store_test.dart;
  preserve current UI fake-store tests and legacy Firestore rule coverage.
- New rules-tests/audio-authority.test.mjs and its package.json test registration:
  exercise the real server REST transaction adapter on a loopback demo project.
- firebase-hosting-merge.yml and web-card-gestures.yml: run the new server tests
  on PR/release; native full Flutter tests already include client tests.
- This plan and a final evidence/remaining-gates review.

Inspect but do not modify firestore.rules, audio_override_store.dart's existing
interface/test-compatible adapter, game engines, Unity and unrelated settings.

## Verification and rollout

1. Reject missing/non-admin/deletion-blocked/revoked identities before writes.
2. Reject invalid slots, cross-slot/external/traversal URLs and missing assets.
3. Transactionally copy committed defaults, not stale UI URLs; preserve backups,
   unrelated fields/settings and old stored backup URL compatibility. Retry only
   explicit transaction conflicts, not ambiguous mutation network failures.
4. Test adapter mapping and errors, full Flutter/Edge suites, Deno and scoped
   analysis; no new dependencies. Check existing Firebase permissions separately.
5. Save/compare current live function source and deploy the tested backend before
   exposing its client path. Preserve existing custom Firebase JWT verification.
6. Build and review web, then publish the narrow fix through the existing PR/CI
   workflow. Do not upload to stores or overwrite native renderer binaries.
7. Repeat the actual signed-in UI upload/save/restore. Read original setting and
   backup state before any save-as-default action; never overwrite an existing
   saved backup merely to test it. Restore the original active choice. Stop for
   direction if a safe original-state restoration path is unavailable.

Rollback is the previous function bundle plus previous client adapter/release;
do not roll back user settings or relax authorization to make a test pass.
Physical-device audio balance and subjective sound latency are separate gates.
