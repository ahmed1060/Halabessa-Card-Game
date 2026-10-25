# Table social UI review

Reviewed locally on 26 October 2026 (Cairo), on development.

## Implemented

- Compact navy/brass room chat over the existing table, with English/Arabic support, room history, game log, quick phrases and keyboard-aware sizing.
- No private teammate channel. Free typing requires every occupied human pair to be mutual friends; bots and empty seats are excluded. Fewer than two humans leaves typing locked. Canonical quick phrases remain available while locked.
- Accepted messages animate beneath the sender avatar (180 ms entrance, 3-second hold, 180 ms exit); old history is not replayed. The local landscape bubble shifts toward adjacent free space to avoid the opponent portrait.
- Themed More menu without the duplicate captured-cards item; the existing capture-history control remains. The leave dialog keeps the existing practice/online behavior and supports cancel, single submission and retry.
- Primary-superadmin-only bilingual quick-phrase management: add, edit, delete, preview and revision conflict handling. Deleting a phrase does not rewrite sent messages.
- Server-side room membership, friendship, fresh administrator identity, canonical preset validation, message rate limits and idempotent retries. Firebase client chat writes and teammate-channel reads/writes are closed. Historical data is retained.
- Related chat-privacy copy and existing CI test commands updated. No game rules, hidden-card payloads, Unity bridge contracts, sounds, scores or timing changed.

## Verification

- Full Flutter suite: 675 passed.
- Backend suite: 306 passed, including 7 focused table-chat policy/CAS tests.
- Firebase database emulator: 19 passed, including obsolete-client bypass rejection and legacy snapshot compatibility.
- After the final bubble-position correction: 18 focused UI/provider/countdown tests passed.
- Supabase Edge entrypoint Deno typecheck passed; CI YAML parsed; git diff whitespace check passed.
- Production lib/main.dart release web build passed. The last bubble-only placement correction is additionally compiled in the final isolated review build.
- Browser review: English landscape, Arabic portrait, locked/friends chat, typed and preset sends, avatar bubble, game menu, leave cancellation, bilingual editor and deletion confirmation. Unity downloaded and ran with the same HUD, with no captured error-level console entries during review.
- Responsive widget cases include 430x850, 850x430 and 320x300, plus reduced motion. Browser screenshots use sample accounts and local-only callbacks; they are not evidence of a production multi-account send.

## Review artifacts

Local preview: http://127.0.0.1:9116/play.html?renderer=flutter&lang=en&socialReview=friends#/game

The top Friends / Locked / Quick Chat manager controls are review-fixture controls only. They are not included in the production entrypoint. Sample sends and phrase edits do not mutate cloud data.

Screenshots and logs are kept in build/table-social-ui-2026-10-25/ (ignored build evidence). Relevant screenshots: chat-friends-landscape.png, chat-locked-ar-portrait.png, quick-chat-manager.png, quick-chat-editor.png, menu-landscape.png and leave-landscape.png.

## Release boundary

This is an uncommitted local development patch. Nothing has been pushed, merged or deployed. main remains the deployed release source. No live messages, friendships or phrase configuration were changed for verification.

After review and explicit release approval, deploy the existing Supabase Edge API first, then Firebase database rules, then the frontend. These are updates to the already connected services, not a new Supabase project. Old clients may lose chat sending when the stricter rules arrive, so release the frontend promptly after backend/rules validation.

Physical Android/iOS installation, keyboard and multi-account cloud checks remain release-validation tasks; they were not performed by this local fixture review.

Final evidence note: the corrected preview compiled successfully (visual-final-build.log) and its 18 focused tests passed. The in-app-browser connection subsequently timed out during the last recapture. Existing screenshots show the reviewed UI before that bubble-only horizontal correction. Final screenshot capture and viewport reset could not be confirmed; a 1280x720 review override may remain until the browser reconnects.
