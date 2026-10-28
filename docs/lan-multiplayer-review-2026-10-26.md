# Same-Wi-Fi mobile multiplayer: local review

Follow-up: Unity presentation is connected in the local 28 October implementation.
See `lan-unity-review-2026-10-28.md`. The Flutter-only limitation below describes
the original 26 October baseline, not the updated LAN renderer.

Status: implemented locally on `development`, with automated and packaging
checks complete. Not committed, pushed, merged, deployed, installed or qualified
on physical phones. The earlier birthday/direct-entry/UTF-8 batch is preserved.

## Implemented flow

Native local-play entry offers Same Wi-Fi. A host creates an in-memory room;
other phones join with its QR, copied invitation or manual details. Nearby-room
discovery is optional and never advertises invitation secrets. Up to four humans
can join; empty seats become Medium bots. Classic and Tafweet use the existing
offline engine. Each viewer receives only their own private hand and the public
table state. Reactions, cut, votes, reveal and slam intents use host validation.

The host is the trusted local authority. Connections use WSS with a per-room
certificate pin contained in the invitation. Private resume credentials retain
a disconnected player's seat; commands have bounded, serialized, revision and
sequence checks with idempotent receipts. Invitations accept private literal
IPv4 addresses only. No cloud authentication, match persistence, rewards, wallet
updates or online-backend protocol changes are introduced.

The host must stay in the foreground: backgrounding or closing it ends the room.
Clients suspend and resume their connection and adopt a fresh snapshot. There is
no host migration or persistence across process death. Network client isolation,
IPv6-only networks and physical platform permission behavior remain device gates.

LAN reuses the current Flutter offline board and its presentation/audio ownership.
The existing offline path deliberately disables Unity; this work does not qualify
or claim a new Unity LAN renderer. Production native gesture defaults are unchanged.
The test APK uses the existing ignored native QA defines for gesture checks.

## Verification

| Check | Result |
| --- | --- |
| Full Flutter suite with the three production gesture flags | 711 passed |
| Final LAN and offline isolation regression run | 37 passed |
| LAN, fixtures and LAN tests: scoped Dart analysis | No issues |
| Backend regression suite | 298 passed |
| Production web build with existing release flags | Passed |
| Memory-only LAN visual review web build | Passed |
| Android normal-entry ARM64 debug build | Passed; 409 Gradle tasks |
| APK single launcher, signature, ZIP/ELF 16 KB alignment | Passed |
| iOS Bonjour/local-network/camera configuration | Source inspected only |

The final focused run includes three real TLS loopback integration tests. They
exercise wrong certificate pin and join secret rejection, private seat resume,
four real connections, fifth-player rejection, per-viewer hand privacy, engine
equivalence for a remote play, off-turn reveal, slam allowance, suspension/resume,
presence and terminal host shutdown. Loopback tests on this PC are not physical
Android/iPhone network tests or an end-to-end full-match playtest.

The final UI regression covers the lobby scroll-position reset. English/Arabic
entry, lobby, manual invitation details and game-mode controls were also reviewed
in browser viewports at 390x844, 320x568 and 850x390. Starting the memory-only
fixture opens the existing board. No camera, real LAN listener, account, cloud
mutation or production room was used for the browser review.

## Local artifacts

All build outputs and logs are ignored, not source artifacts for release:

- `build/lan-2026-10-26/halabessa-lan-arm64-debug.apk`
  (266,120,027 bytes; SHA256
  `07d9aa6665af39e47c79669343f3159d5e45fb1f92e51b12eeaa1f11c74f8150`).
  Package `com.halabessa.game`, one MainActivity launcher, min SDK 24, target 36,
  ARM64, debug signed. Includes camera, internet, vibration and multicast
  permissions. Does not replace the separately preserved pre-LAN birthday APK.
- `build/lan-2026-10-26/review/`: memory-only visual fixture served on port 9119.
  Its invitation/QR is dummy review data, not a room another phone can join.
  Main `main.91b323705a239402.dart.js`, bootstrap
  `flutter_bootstrap.aac9f5d5959593bc.js`.
- `build/lan-2026-10-26/production/`: normal web entry; mobile-only LAN remains
  excluded from product browser navigation. Main
  `main.5decaef325d70411.dart.js`, bootstrap
  `flutter_bootstrap.266edfc4e9370148.js`.
- Screenshots in the same LAN build folder: English entry/lobby/manual details,
  Arabic small entry/lobby and landscape controls/board.
- `build/table-social-ui-2026-10-25/lan-final-focused-tests.log`,
  `lan-flutter-full.log`, `lan-backend-tests.log`, `lan-analysis-final.log`,
  `lan-android-final.log`, `lan-apk-verification.log`,
  `lan-review-final-build.log`, `lan-production-final-build.log`.

Earlier Android attempts failed on dependency DNS/downloads; a later successful
build resolved them without changing Gradle, AGP, Kotlin, Java, TLS verification
or global network settings. Native Gradle report output under `android/build/`
is explicitly ignored so generated reports cannot enter a future source commit.

## Remaining before release

1. Install on two or more phones and play complete Classic and Tafweet matches,
   including all deck rounds, voting, bots, reveal/slam allowances and exit flows.
2. Qualify Android nearby discovery, first-run QR scanning without internet,
   denied camera permission/manual joining, reconnect, audio and haptics.
3. Build with Xcode and qualify iOS local-network/camera permissions, discovery,
   QR scanning, host/client background/resume and mixed Android/iPhone rooms.
4. Review and approve this local feature plus the separate birthday/UTF-8 batch;
   then run release CI and merge/deploy through the existing two-branch workflow.

GameEngine, Deck, BotBrain, game actions, online room authority and Unity source
were not changed by LAN. The only engine-facing extensions initialize a scoped
local match, tick its existing host evaluator and update local presence. An
explicit offline chat-provider override also prevents inherited cloud streams in
the existing nested Practice/LAN containers.
