# Audio authorization review

The existing sound upload succeeded, but its subsequent direct Firestore write
was denied. Audio setting writes now use the backend's existing admin admission,
with a fresh active Firebase identity, deletion guards and fixed audio targets.
Firestore listeners and rules are unchanged. No client receives server credentials.

The backend accepts only the existing 16 logical slots. New replacements must
reference an immutable file in the configured project's matching Storage slot,
with a successful size/MIME check. Saved defaults copy committed Firestore state
inside a transaction, preserving existing legacy metadata. Bundled restore deletes
only the active pointer. Only explicit transaction conflicts retry; ambiguous
mutation failures do not retry automatically.

## Local evidence

- 244 Edge/backend tests passed, including 12 audio authorization/adapter tests.
- All 662 Flutter tests passed with the three production card-interaction flags.
- 47 Firestore/Realtime Database emulator tests passed, including actual REST
  save/replace/restore transactions for SFX and both music categories.
- Scoped Dart analysis and the complete Deno 2.5.4 entrypoint check passed.
- Production-flag web release build succeeded. Existing dependency WebAssembly
  compatibility warnings do not prevent the normal JavaScript release build.
- No dependency versions, Firebase rules, roles, gameplay, Unity exports, sound
  bytes or chat UI were changed. Unrelated preexisting local edits are excluded.

The emulator's GET transaction-query transcoding failed with BYTE_STRING;
the adapter uses the documented POST batchGet transaction body instead. This
path passed the actual emulator tests, rather than only mocked fetch responses.

## Release gates

Baseline live Edge function is version 69. Of its 37 files, only index.ts differs;
audio_settings.ts is the sole additional file. A local rollback source snapshot
exists in the ignored build directory. Deploy backend before the client release;
preserve its existing verify_jwt=false because Firebase tokens are verified inside
the function. Verify deployed source and unauthenticated rejection after deploy.

PR CI, main Hosting deployment and actual signed-in browser upload/reset remain
release checks at the time of this review. Do not overwrite an existing saved
backup merely to test save-as-default. Restore the original active choice after
testing. Physical-device sound/haptic checks remain separate from these tests.
