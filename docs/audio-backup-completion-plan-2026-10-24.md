# Finish audio backups and acceptance — local only

Baseline: `build/lantern-remote-final`, existing dirty card/audio changes preserved.
Selected defaults and local preview are complete; remaining source defect is the
trusted upload handler overwriting the same audio object referenced by backups.
The user now authorizes continuation and has an Android phone available.

## Changes

1. Extract only the existing asset upload operation into
   `supabase/functions/halabessa-api/asset_upload.ts`, imported by `index.ts`.
   Preserve verified caller/admin admission, avatar UID policy, store-item behavior,
   byte limits and credential isolation. Audio gets a server-generated versioned
   path and `x-upsert: false`; storage failure must not publish an override or
   overwrite an existing object. Existing uploaded URLs remain readable.
2. Introduce a narrow injectable audio-settings store in
   `lib/core/services/audio_override_store.dart`. Route only audio-specific save,
   saved-default and reset operations through it. Use Firestore transactions for
   active-to-backup/default restore, reading the committed document rather than a
   stale UI snapshot. Keep legacy schema/read compatibility and explicit built-in
   restore. No changes to game configuration, rules or authority.
3. Make the existing two-stage admin upload/save flow injectable in
   `lib/core/services/admin_audio_upload_service.dart` and use it from the two
   management screens. Test upload failure, settings failure, replacement, marking,
   saved-default restore and bundled reset without any live mutation.
4. Add Node tests exercising the actual upload implementation with local fake
   Storage transport and local Firestore emulator authorization/restore tests;
   add Flutter tests of the actual notifier and upload coordinator with an
   in-memory persistence adapter. Extend existing render tests as needed.
5. Re-run regressions/static checks and inspect Android via ADB. Prepare an isolated
   QA artifact if necessary; do not replace an existing valued app installation,
   uninstall/clear user data or publish. Ask for device action/approval only when
   the exact installation target and risk are known.

## Protected presentation and security boundary

No animation windup/flight/contact/settle times, easing, audio/haptic ownership,
bridge privacy/version/order/ACK, turns, deck counts, commands or scores change.
Both renderers continue to use the same Flutter audio owner. No new dependency,
database migration, live storage setting, service-role exposure or authorization
weakening. The Supabase guidance recommends new paths to avoid overwrite/CDN
staleness; current changelog and upload docs were checked before implementation.

## Acceptance and limits

Require distinct audio paths even for same-slot/concurrent replacements, no-upsert
collision handling, MIME/size validation, existing image behavior, exact saved
default restore and unrelated-setting preservation; denial for ordinary/anonymous
users in emulator rules tests. Legacy audio bytes overwritten before this fix
cannot be reconstructed: retain bundled choices and report that limitation.

Real production admin upload/restore and Mac/Xcode/iPhone checks remain separate
gates. Local emulation is not reported as a production test. No commit, push,
merge, hosting deployment, function deployment or store upload is authorized.
Rollback is reverting this audio-only patch; never roll storage back to overwrites
after relying on immutable backups. Device work is separate from source completion.
