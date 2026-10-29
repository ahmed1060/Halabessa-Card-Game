# Unity presentation for mobile LAN

Work locally on development. Preserve the existing birthday/UTF-8 and LAN work.
The current LAN WSS authority/projection is implemented; its local navigator
currently suppresses Unity and has no platform view. The native online root has
a persistent Unity view, but that view cannot consume a nested LAN private scope.
Unity 6000.0.69f1 is now connected to the root unity/Halabessa project.

## Outcome and protected boundary

Mount one Unity view behind the existing LAN board, inside the same private
viewer scope. Keep Flutter HUD/hit targets and all current card animations,
layout, audio/haptic ownership and fallback. Respect the saved 3D/reduced-motion
settings. Local Practice retains its existing Flutter default. No cloud access,
new dependencies, rules, ownership, command validation, timers, scoring, votes,
allowances, host lifecycle or network protocol changes.

Use only LanReplicaNotifier's viewer snapshot, never LanMatchDriver's complete
host state. The LAN room revision may label the replica's presentation revision;
it must not alter host state or authorize moves. Bridge input still forwards
through the replica and existing host intent validator. ACKs remain cosmetic.

## Existing visual beat sheet

Retain approved existing timings: ordinary native CardPlayed flight/settle 350ms;
CardDrawn 600ms; refined slam 500ms (legacy feel 470ms); capture reading contact
220ms before the existing local hold; typed collection 1400ms. Existing cut and
shuffle sequences remain owned by the Flutter deck presentation. Public reveal
keeps the same card playable and uses the negotiated refined native hand. Audio
and haptics remain Flutter CardFeedback-owned, with current leases/deduplication.
No new motion profile, domain delay or artificial pause. Reduced motion removes
shake and compresses motion as today. Existing visual queue allowance is 350ms;
timeout cancels/catches up without disabling later native effects.

## Exact file map

- New lib/features/lan/presentation/lan_unity_surface.dart: scoped renderer
  overrides plus one overlay/board composition; suppress visuals while a client
  reconnects. Add explicit test seams for a fake view/recording bridge.
- lib/features/lan/presentation/lan_play_app.dart: use the scoped presentation
  surface in _LanTable; default mobile Unity enabled, explicit QA opt-out.
- lib/core/providers/native_play_provider.dart and game_board_screen.dart: small
  local renderer opt-in, keeping Practice unchanged and 3D setting respected.
- settings_overlay.dart: show the existing 3D toggle for the opted-in LAN viewer;
  Practice retains its existing settings and no new preference is introduced.
- unity_layer_provider.dart and unity_game_view.dart: connection suspension joins
  the existing lifecycle gate, preventing stale cards/effects during catch-up.
- unity_communication_service.dart: request a native READY handshake on a new
  controller; ignore disposed callbacks. Retain legacy startup and input support.
- unity/Halabessa/Assets/Scripts/UnityBridge.cs: optional REQUEST_READY message,
  clear old renderer-only state and repeat the existing capability announcements
  on a warm native remount. No scene/prefab/artwork or engine edits.
- lan_match_adapter.dart: label only the replica presentation revision from its
  already validated room revision.
- LAN/Unity tests and tool/lan_review.dart: scope/privacy, intent routing,
  handshake, reconnect/no replay, failure/2D, one view and English/Arabic review.

Inspect but do not modify GameEngine/Deck/BotBrain/actions, lan_room/protocol/TLS,
cloud backend/rules, selected audio, C# timing and authoritative state. Existing
dirty files in those areas belong to the previous approved batch.

## Bridge and lifecycle

Keep protocol 1 snapshots/actions, generation/room/round/event identity and
capability negotiation. REQUEST_READY is optional and native-only; old builds
ignore it and still use their existing startup READY behavior. Warm upgraded
players cancel old tweens, clear private card objects and generation history,
then announce the same READY/capabilities. Do not treat controller creation or
an ACK as readiness. Missing/failing Unity keeps the Flutter board visible.

Disconnect cancels presentation; fresh reconnection adopts the current private
snapshot without replaying missed sound/effects. Host background still ends the
room. Keep one view during connected/reconnecting play; dispose on room exit.
Re-entering another room requests a fresh handshake from the retained native
engine. Stale ACKs and disposed callbacks cannot change rules or old room state.

Responsive-review refinement: camera resizing can lag Flutter's normalized
anchors by a frame. UnityBridge.Update emits an optional UNITY_VIEWPORT_CHANGED
signal once Screen dimensions change; Flutter cancels/reconciles its current
visual snapshot in the same generation-managed layout. Old builds ignore the
extension. No delayed gameplay, new motion profile or network message is added.

## Verification and rollback

First recording-bridge/fake-view tests, then real private LAN socket traces and
existing renderer regressions; run the full Flutter suite with release flags.
Compile the C# extension through the connected Editor. Export fresh players to
new ignored build/lan-unity-2026-10-28 folders, verify/restore source settings and
prepare an isolated Android APK. Browser fixture may explicitly select Unity for
visual QA, but product LAN remains mobile-only. No live rooms/accounts/writes.

Physical Android/iPhone Wi-Fi, native surface compositing, gestures, audio and
haptics remain device gates until hardware is available; Windows cannot run
Xcode. No commit/push/deploy/install. Rollback is the LAN local renderer opt-in;
the existing Flutter fallback, LAN host and online path remain available.

## Local completion

Implemented and verified in `lan-unity-review-2026-10-28.md`: 712 final Flutter
tests, 20 connected-Editor renderer checks, fresh Android/iOS/WebGL exports,
verified Android APK, private scoped bridge, reconnect/failure handling and a
visually confirmed portrait/landscape camera-resize correction. Protected source
hashes match and the Editor target is WebGL again. Physical device and approved
release packaging gates remain open. Nothing has been pushed or deployed.
