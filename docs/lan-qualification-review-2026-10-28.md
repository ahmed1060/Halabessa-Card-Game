# LAN qualification results — 28 October 2026

Follow-up: [Unity export integration](unity-export-integration-review-2026-10-28.md)
now records the locally integrated shipping players, recovery archive and build
guards. The staging-only status below describes this earlier qualification batch.

Local development work only. No push, merge, deployment, installation, production
feature-flag change or shipping Unity export replacement occurred in this batch.
Earlier uncommitted birthday, UTF-8 and LAN/Unity changes are preserved.

## Real host and TLS qualification

The actual LanMatchDriver and existing engine ran over pinned TLS loopback
sockets on Windows. Four human clients completed Classic and Tafweet matches
with production timers unchanged. This is stronger than the simulated browser
review, but does not establish physical Wi-Fi or mobile renderer performance.

- Classic: 16 complete decks, final score 45:36, rematch declined cleanly.
- Tafweet: 8 complete decks, final score 44:39, rematch declined cleanly.
- Two humans plus two host-controlled bots: one complete deck, score 6:2.
- Total: 25 decks / 75 hands / 1,200 played cards; each completed deck conserved
  all 52 unique cards and contained exactly 48 plays across hands 1, 2 and 3.
- Each private viewer received only its own hand. Reveals stayed playable;
  every human's fourth reveal was rejected, three slam uses were enforced and
  the allowances reset for the next full deck. Peer suspend/resume retained the
  original seat and remaining allowance. Existing shuffle voting progressed.
- Accepted manually submitted plays matched GameEngine cards, board, turn and
  scores at their committed state. The host's last-card auto-play remained active.
- Firebase.apps stayed empty and earnedCoins/earnedStars stayed empty throughout.

Evidence under ignored build/lan-unity-2026-10-28:
full-match-tests.log (two full matches, 15m14s total) and bot-deck-test.log
(43s). Early harness attempts are retained as full-match-harness-first.log;
those exposed stale-view and auto-play timing assumptions in the tests, not a
game rule change. No runtime source was changed to make these tests pass.

Final scoped analyzer: no issues. The focused TLS suite also passed all three
tests; the three slow opt-in cases were correctly skipped in that ordinary run.
The full-match and bot evidence above comes from their explicit execution, not
from those skips. Final git diff --check passed (line-ending notices only).

The final test/lan_full_match_test.dart makes these deliberately slow tests
opt-in. To run all three on a developer machine:

```powershell
$env:PUB_CACHE = "$PWD/build/pub-cache"
& build/flutter-sdk/bin/flutter.bat test --no-pub --reporter expanded `
  --dart-define=HALABESSA_LAN_FULL_MATCH_QA=true `
  --dart-define=HALABESSA_CARD_INTERACTIONS=true `
  --dart-define=HALABESSA_CARD_UI_REFINEMENTS=true `
  --dart-define=HALABESSA_ONLINE_CARD_INTERACTIONS=true `
  test/lan_full_match_test.dart
```

## Export staging and Android package

tool/prepare_unity_release.mjs checks successful zero-error export reports,
native capability markers, ARM64 ELF headers, a real Brotli WebAssembly player,
WebGL data capability markers and the iOS static archive. It rejects Git LFS
pointers, stale/mutated payloads, changed Unity sources, overwrite attempts and
staging outside the ignored build directory. Seven Node tests passed:

```powershell
node --test tool/prepare_unity_release.test.mjs
node tool/prepare_unity_release.mjs prepare `
  build/lan-unity-2026-10-28 build/<new-candidate-folder>
node tool/prepare_unity_release.mjs verify build/<candidate-folder>
```

Final clean candidate: build/lan-release-candidate-final-2026-10-28. Manifest
covers 3,149 payload files (1,063,243,427 bytes) and hashes 781 Unity source files.
The source hash is observed at staging; previous export reports do not attest a
source hash, and the manifest explicitly says so. It does not certify arbitrary
exports as built from that exact source. Rebuild if provenance is uncertain.
The source/export connection here is supported by the previous connected Editor
exports, unchanged source, current markers and native metadata verification.

Android staging excludes the Windows IL2CPP compiler, build caches, symbols and
obsolete Firebase remnants. It keeps the current portable Gradle integration
with fresh precompiled ARM64 libraries. Its optional unityRebuildIl2Cpp path is
not supported by this precompiled payload. AGP's local .cxx working cache is
excluded from release verification; every actual payload byte remains checked.

An APK built from the initial staged package succeeded in 5m06s (408 tasks),
without rebuilding Unity IL2CPP. All declared staged payload hashes still match
after this build. The final candidate uses the same payload bytes; the final
manifest additionally records the iOS portability gate discovered during review.

APK: build/lan-unity-2026-10-28/halabessa-lan-staged-arm64-debug.apk,
287,433,164 bytes, SHA256
22b459f0753cf26f1f69ca19e3149b29768f86029e1f7342091382b0556942ee.
Normal app entrypoint, debug signature, ARM64 only, minSdk24/targetSdk36, one
MainActivity launcher, ZIP/ELF 16 KB alignment and exact fresh Unity metadata
all passed. Logs: staged-apk-build.log and staged-apk-verification.log.
QA gesture defines remain confined to this local test artifact.

## Remaining gates

The manifest deliberately has releaseReady=false. Shipping paths still differ
from the fresh Android/iOS and most WebGL payloads. Promotion needs an explicit
integration review before a release merge; current workflows consume those
shipping paths and do not rebuild Unity from C# source automatically.

Fresh iOS contains no Unity Firebase dependency, while the existing Flutter
Podfile has compatibility scaffolding for the older Unity Firebase export.
Reconcile the project/Podfile when promoting it. The generated Xcode project also
contains the Windows exporter's symbol-tool argument; this is recorded as a
portability gate, not silently treated as a qualified Mac build. Xcode compile,
framework embedding and iPhone launch cannot be verified on this Windows PC.

ADB again detected no connected phone. Physical Android/iPhone same-Wi-Fi rooms,
discovery, QR scan, first-use permissions, background/reconnect, native Unity
compositing, gestures, sound and haptics remain open. No device has been installed
or real user/cloud data changed by these tests.
