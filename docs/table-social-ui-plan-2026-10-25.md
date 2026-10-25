# Approved table social UI — implementation plan (2026-10-25)

The user approved the generated room-chat/menu/leave and superadmin Quick Chat
mockups. Use the corrected second sheet (room chat + game log, no team tab) and
exec-cb400a81-1df9-44ae-9b00-aa26a5b148da.png for phrase administration.
Development baseline bd6ba74d is clean. Both renderers consume the same Flutter HUD.

## Protected scope

No changes to game rules, move command semantics, server turns/timers, points,
card ownership/visibility, rewards, votes, leave penalties or Unity bridge.
Chat authorization is the explicitly approved functional extension: one room-wide
channel, typing only if every occupied human pair is mutually friends. Bots and
waiting seats are excluded; fewer than two humans keeps typing locked. Quick
phrases stay available to seated online players. Practice stays cloud-isolated.

## Presentation beats

- Compact anchored navy/brass chat panel: 180 ms easeOut reveal, no full-screen
  input barrier; bounded height, keyboard-safe portrait/landscape scrolling.
- Public avatar message: 180 ms fade/slide in, 3 s hold, 180 ms fade/slide out.
  One current bubble per sender, new accepted messages replace that sender only.
  Game-log switching does not replay or suppress live room bubbles. No old
  transcript replay on subscribe. Reduced motion uses immediate changes.
- Menu: existing Flutter popup route, navy/brass style, icon rows for settings,
  reactions, existing online room code, coral leave. Captures stay accessible
  through the existing top-right capture control, never the menu.
- Leave: themed compact dialog, mint Stay, coral outline Leave, existing warning
  and leave command; prevent double-submit, show failure and keep dialog open.
- No extra audio/haptic cue or Unity host motion. No gameplay catch-up budget
  changes. Bubble replacement is bounded to one event per sender, no queue.

## Exact file map

New:
- supabase/functions/halabessa-api/table_chat.ts (pure chat/preset policy + CAS adapter)
- lib/features/game/domain/models/quick_chat_phrase.dart
- lib/features/game/presentation/providers/quick_chat_providers.dart
- lib/features/game/presentation/widgets/table_chat_bubble.dart
- lib/features/game/presentation/widgets/table_leave_dialog.dart
- lib/features/home/presentation/pages/admin_quick_chat_screen.dart
- functions/test/edge_table_chat.test.ts
- test/table_chat_ui_test.dart and test/quick_chat_policy_test.dart

Small extensions:
- supabase/functions/halabessa-api/index.ts (authenticated chat actions and SQL
  participant/friendship reads, primary-superadmin identity check)
- database.rules.json (server-only chat writes/presets; deny team chat reads)
- lib/core/services/backend_transport.dart (classify chat/preset reads)
- lib/features/game/domain/models/chat_message.dart (preset ID metadata)
- lib/features/game/data/repositories/multiplayer_sync_service.dart (trusted send)
- lib/features/game/presentation/providers/chat_providers.dart (room-only stream,
  separate game log, policy refresh and deduplicated timed avatar bubbles)
- lib/features/game/presentation/widgets/chat_overlay.dart (compact themed UI)
- lib/features/game/presentation/widgets/table_seat.dart (animated ivory bubble)
- lib/features/game/presentation/pages/game_board_screen.dart (menu/leave wiring)
- lib/core/routes/app_routes.dart and lib/core/widgets/settings_overlay.dart
  (superadmin Quick Chat destination)
- assets/translations/{en-US,ar-EG,ar-SA}.json
- rules-tests permissions fixtures/tests and tool/option_b_preview.dart as needed
  for isolated UI evidence; no live accounts or production data for testing.

Inspect only: all game/domain engines, Unity scripts/scenes, gesture/audio code,
room progress/publication logic, sound settings. Reuse current Firebase-authenticated
Supabase Edge backend; no additional backend project or package dependency.

## Backend/transport contract

Keep existing room-wide Firebase message reads and frozen public history. Block
all client writes and all private-team reads/writes. Server sends validate active
room membership and complete mutual friendship for free text on every send.
Quick messages accept only a current preset ID + locale; canonical text comes
from trusted configuration, never a client isQuickChat flag. Presets are bilingual,
revisioned, bounded, and stored under a server-only Firebase config root; delete
removes a preset without rewriting already sent messages. Primary superadmin is
checked against fresh Firebase identity; delegated admin is insufficient.
Use existing Firebase ETag conditional writes for rate limiting and message
idempotency. Same-ID retry cannot duplicate a bubble; failed sends are not shown
as accepted. Policy refreshes while open, on roster change and after rejection;
server remains authoritative if the displayed policy is momentarily stale.
No new Unity events, capabilities, acknowledgements or hidden card payloads.

## Sequence and acceptance

1. Add pure server policy/CAS tests and a fail-closed client adapter.
2. Connect canonical phrases and room-only reads, then themed panel/bubbles.
3. Add superadmin bilingual add/edit/delete with conflict/permission handling.
4. Restyle menu/leave without changing their commands.
5. Run backend policy, Firebase emulator permissions, focused Flutter tests,
   analysis, full regressions, fresh preview builds for both renderers, English
   and Arabic, portrait/landscape, keyboard/reduced motion. Verify non-friends,
   friendship between every pair, spoofed presets/team requests, unauthorized
   admins, concurrent sends/conflicts and offline zero-cloud behavior.
6. Review screenshots against approved sheets and report device limits truthfully.

Rollback is the single unreleased development patch; keep main/live unchanged.
Backend + rules must be released before a future frontend rollout, only after
user review/approval. No production deployment is part of this local work.

Implementation-discovered additions: tool/table_social_review_panels.dart is a
cloud-fenced fixture imported only by the local preview. Existing chat-visibility
copy in assets/legal/{privacy,terms}.json and generated web/{privacy,terms}.html
is updated to describe room-only chat. The source-equivalence test ignores Git's
Windows CRLF conversion. The existing emote expiry regression now waits for the
approved exit fade. No other policy terms or gameplay deadline changed.

The existing development web validation and main Hosting check also run the new
server chat tests; development web validation includes chat UI/provider/expiry
regressions. Hosting remains main-only. No workflow is pushed during local review.

Visual acceptance correction: the local landscape bubble shifts 80 logical units
toward the adjacent open table space to clear the left opponent portrait. This
changes only bubble placement; all seats, cards and rules stay fixed.
