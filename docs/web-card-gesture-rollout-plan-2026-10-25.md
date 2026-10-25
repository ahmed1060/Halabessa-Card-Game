# Web gestures: online and practice rollout

## Authorization and baseline

The user approved enabling swipe-up, swipe-down reveal and long-press slam in
both online rooms and practice, after the live website was shown to retain
default-off flags, offline-only UI gates and the 21 October Unity export.
Active checkout: `build/lantern-remote-final`, branch
`codex/web-card-gesture-rollout`, base main `3549450e`. Existing unrelated dirty
analyzer/platform/Gradle files remain untouched and excluded from commits.

Live Supabase `halabessa-api` version 68 is saved in the ignored local build
directory for rollback. Its normal game engine/lifecycle match current source;
the pending differences are the already-approved reveal/slam metadata, private
delivery/deletion cleanup and immutable admin audio upload protection.

## Protected boundaries

Do not modify rules, turns, deadlines, card membership, scoring, bot strategy,
votes, ownership validation or auth/permission policies. Use the existing
authenticated command path, per-player three reveals AND three slams per full
52-card cycle. Reveal does not play a card. Queues remain local/private and
dispatch only when a real turn permits. Rejected actions consume no allowance.
No new live account/room, schema migration, dependency or app-store publication.

## Existing approved beat sheet (retain, do not retune)

| Action | Flutter / Unity sequence | Completion and feedback |
| --- | --- | --- |
| Swipe up, off turn | Drag/lift -> retained raised queue | No public move; tap cancels; existing turn-entry cancellation window |
| Swipe up, on turn | Existing release-origin cubic flight to center | Accepted command remains authoritative; one renderer/contact owner |
| Swipe down | Existing near-camera reveal -> physical-right held-card slot | Same owned card remains playable; peers see only accepted public faces |
| Long press | Existing pulse/shiver -> private slam intent | Stop hold haptic when armed; off-turn intent queues privately |
| Slam | 140 ms windup -> 160 ms strike -> 50 ms hold -> 150 ms settle | Existing single contact audio/haptic, no global shake/time-scale changes |
| Reduced motion | Existing compressed/snap paths | Keep identity, acceptance, visibility and single feedback intact |

Existing bounded Unity queue/ACK recovery budgets remain unchanged. No cosmetic
wait may extend a server turn or turn an acknowledgement into a game command.

## File-touch map and bridge contract

- New `card_interaction_policy.dart`: one shared policy for explicit build flags,
  offline practice or server-command online rooms; exclude legacy online state.
- `game_board_screen.dart`: replace only offline-preview feature checks with
  shared policy; retain spectator and Unity capability checks and event identity.
- `unity_communication_service.dart`: same shared policy for visual acceptance.
- `web/Build/*`: copy the already-tested 24 October isolated WebGL export into
  the existing shipping filenames; verify binary hashes and negotiated v1 cues.
- `web/index.html`: change asset version identifier/loader URL together so the
  new loader/data/framework/WASM cannot be confused with the old export.
- `web/unity-release.json` and `web_card_gesture_rollout.test.mjs`: verify export
  hashes, source provenance, valid WASM, release defines and matching asset URLs.
- `tool/serve_card_ui_preview.dart`: serve compressed `.unityweb` files using
  the same Brotli/MIME headers as Hosting for an accurate local browser check.
- `.github/workflows/firebase-hosting-merge.yml`: explicit web-only gesture,
  refinement and online rollout defines; native defaults remain unchanged.
- `.github/workflows/web-card-gestures.yml`: verify the exact web release flags,
  payloads, privacy and production-entrypoint build on PRs before main exposure.
- Tests: online/practice/legacy/spectator/capability matrix, queued cancellation,
  two-recipient privacy delivery, legal/slam invariant replay, disabled rollback,
  exported-file/cache agreement and existing startup/failure regressions.

Retain `UNITY_CARD_INTERACTIONS_READY`/`UNITY_CARD_UI_READY` negotiation and legacy
messages. Send local hand IDs only; other faces must already be accepted public
reveals. Completion, replay, cancellation, late ACK and fallback semantics stay.

## Release order, acceptance and rollback

1. Inspect saved live bundle vs tested server source; run all Edge tests and Deno
   checks before deploying that existing function. Preserve its current
   `verify_jwt=false` because the body still verifies Firebase ID tokens itself;
   this is not a new auth bypass. Confirm unauthenticated requests still fail.
2. Introduce the shared disabled-by-default online adapter and regression tests.
   Verify Flutter and Unity independently in isolated local rooms/recipient tests.
3. Verify the existing 24 October WebGL export/source provenance, package it with
   fresh URLs and build the actual production entrypoint using release defines.
4. Check CI before main merge. Deploy the function before exposing web handlers;
   verify the published web flags/assets/capability handshake after Hosting.
5. Report source/unit/browser evidence separately from actual two-phone, physical
   vibration or speaker-latency checks; those are not implied by CI.

Rollback online gestures with `HALABESSA_ONLINE_CARD_INTERACTIONS=false`; rollback
all special handlers with `HALABESSA_CARD_INTERACTIONS=false`. Retain existing
Flutter fallback on Unity failure. Never roll back database/user game state.
