# Same-Wi-Fi mobile multiplayer

The user selected the previously approved Stage 3 ahead of publishing the current
birthday/UTF-8 batch. Work stays local on development; preserve that entire dirty
batch. No new branches, worktrees, cloud projects, accounts, deployment or paid
service. Android/iOS only in the product; loopback sockets are permitted for QA.

## Baseline and protected boundaries

Existing MatchStateNotifier owns local Practice progression through GameEngine,
Deck, BotBrain, phase/capture holds, last-card handling and voting. Offline IDs
fence cloud rewards and remote sync. MatchState.toJson excludes handCards;
existing public counts and reveal metadata support a private viewer projection.
The current offline navigator deliberately uses Flutter presentation and bundled
assets. Reuse that board and all gesture/audio/haptic timing without claiming a
new Unity-native qualification. Online Supabase authority remains untouched.

Keep rules, turn/capture/scoring/win conditions, deck counts, votes, allowances,
online protocol and economy unchanged. The host is the trusted local authority,
never a client-side replacement for the online backend. LAN IDs use a distinct
OFFLINE_LAN_ namespace so existing cloud/economy guards remain effective.

## Connection and privacy

Native WSS listener with an ephemeral self-signed certificate. Invitation QR/text
contains local address, port, room identity, SHA256 certificate pin and a random
join secret. Accept only that exact certificate, not arbitrary bad certificates.
Only literal local/private addresses (plus loopback for QA) are accepted; no
redirects, external invitation links, cloud authentication or global TLS overrides.
Generate credentials on the host using vetted package primitives, never static
keys. Advertise only public room identity/name through Bonjour/NSD. Discovery is
a convenience; joining still requires the invitation. No invitation secrets in
service advertisements, logs, public snapshots or another player's messages.

Host assigns seat and opaque local UID. Give each human a private random resume
credential; a shared invitation cannot reclaim someone else's seat. Bound frame
size, admission count/time, nickname length and command rate. Serialize commands;
bind identity to the authenticated socket; require protocol/version/revision and
sequence; cache bounded idempotent results and reject changed-ID replays. Never
accept client snapshots, dealer/deal/advance/bot/score mutations. Per-viewer
snapshots contain only that viewer's hand, public counts and accepted reveals.

Host retains full engine state in memory. Disconnect retains the seat for resume;
an explicit guest leave during active play ends the local match cleanly. Lobby
departures release their seat. Host stop/background closes the room, without
background keepalive or pretending it is still playable. Client reconnects by
private credential and adopts a fresh snapshot; no host migration or economy
settlement. Host owns timeouts; peer display timestamps are translated from a
host clock sample, and peer clocks never authorize progression.

## Product flow and exact file map

New lib/features/lan/domain/lan_protocol.dart: bounded invitation/messages,
membership/revisions, private snapshots and clock projection.
New lib/features/lan/data/lan_tls.dart, lan_socket_transport.dart,
lan_discovery.dart: ephemeral TLS, native WSS connection and NSD lifecycle.
Conditional native/stub exports keep dart:io out of the browser product build.
New lib/features/lan/presentation/lan_match_adapter.dart: host engine integration
and read-only remote notifier with intent forwarding; no private engine copy.
New lib/features/lan/presentation/lan_play_app.dart: themed create/join/lobby,
nearby list, invitation QR/copy/paste/manual entry, scanning on explicit tap,
connection/reconnect/host-ended surfaces and the existing board navigator.

Small extensions: MatchStateNotifier gains an explicit local-session initializer
and host tick hook; offlinePlayOverrides accepts a scoped notifier factory;
NativePlayEntry gains Same Wi-Fi after choosing local play and its age gate.
Add local-only UI copy to en-US/ar-EG/ar-SA; Android manifest local networking
permissions; iOS Bonjour/local-network/camera purpose copy. Add only the native
discovery/scanning, QR rendering and certificate helper dependencies and their
resolved lock entries. No Unity, cloud rules, online transport or wallet edits.

Inspect but do not modify GameEngine, Deck, BotBrain, GameAction, online room
protocol, Supabase functions, Firebase rules and the Unity bridge. Existing dirty
rule/header edits belong exclusively to the earlier birthday/UTF-8 batch.

## Presentation and bridge contract

No new card motion or bridge event. Current windup, flight/contact/settle, sound
and haptic ownership remain with the reused board. No artificial gameplay delay
for network animation acknowledgements. Connection state changes have ordinary
Material focus/scroll behavior and honor reduced motion. Reconnect replaces the
projection with the latest accepted revision rather than replaying old effects.
Existing bridge identity, fallbacks and old message support remain unchanged.

## Implementation and acceptance

1. Add protocol/TLS transport with loopback integration tests before enabling UI.
2. Connect a single host engine and remote play, then reveal/slam/cut/votes/reactions.
3. Add lobby/bots/permissions/discovery/QR/manual joining and clean lifecycle exits.
4. Test four seats, private hands, spoofing, stale/duplicate/concurrent commands,
   reconnect, host loss, max sizes and complete local round invariants. Run with
   cloud providers configured to throw; no local result may produce rewards.
5. Check English/Arabic narrow/landscape layouts, default and production-flag
   regressions, browser compile isolation, Android build/manifest and iOS source
   configuration. Keep physical Android+iPhone Wi-Fi/permissions/scanning/resume
   and audible/haptic checks explicitly outstanding until devices are available.

Rollback removes the LAN entry/adapter and scoped files/dependencies. Existing
Practice, Online, birthday changes and their data remain intact. No LAN listener
or discovery starts until the player explicitly enters that mode.

References checked: Dart HttpClient/WebSocket/SecurityContext API, nsd 5.0.1,
basic_utils 5.8.2 X509/CryptoUtils, qr_flutter 4.1.0 and mobile_scanner 7.4.2
publisher documentation. Keep scanner assets bundled for offline scanning.

Implementation file-map refinement: lan_room.dart holds the host admission and
command ledger separately from parsing; lan_connection.dart defines the platform
boundary and lan_socket_native.dart/lan_socket_stub.dart implement it. Extend the
existing table_leave_dialog.dart and its game_board_screen.dart call site only
with LAN-specific exit wording. These changes retain the existing visual timing.

Additional integration details: explicitly fence the newer room-chat/policy
providers in the existing offline override list. This preserves the intended
zero-cloud boundary for both Practice and LAN, including nested provider scopes.
The replica emits the existing fallback SFX cues; current presentation audio
leases still suppress duplicate cut/shuffle/play/capture playback. No new sound
asset or animation timing is introduced. Client suspension retains its private
resume token and pending command identity but stops sockets/retry activity until
foreground. A small Android gradle.properties entry explicitly keeps the QR
scanner model bundled, and factual English/Arabic privacy copy describes the
local host and local-network/camera usage. No cloud permission/rule is added.

Local implementation and automated/build verification are complete. See
`lan-multiplayer-review-2026-10-26.md` for the 711-test full run, final 37-test
focused run, 298 backend regressions, successful Android APK verification,
responsive visual review and the outstanding physical Android/iOS release gates.
This is not a physical-device qualification or a published release.
