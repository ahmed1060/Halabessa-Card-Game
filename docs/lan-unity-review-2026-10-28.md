# Unity LAN presentation: local verification

Local development work only. No commit, push, merge, deployment, installation,
account changes or cloud test writes. Preserve the separate birthday/UTF-8 batch.
This follow-up supersedes the Flutter-only limitation in the 26 October LAN review.

The subsequent [LAN qualification review](lan-qualification-review-2026-10-28.md)
records complete Classic/Tafweet matches, a bot-filled deck, current player
staging and the successful Android build from that staged package. Refer to its
remaining gates before promoting native or web players for release.

The subsequent [export integration review](unity-export-integration-review-2026-10-28.md)
records their local integration into shipping paths, the recovery archive and
final Android package. It retains the Mac, clean native CI and physical-device gates.

## Implementation

Mobile LAN now opts into Unity when the existing 3D preference is enabled. Its
single persistent view lives beneath the LAN Navigator in the private viewer's
provider scope, rather than consuming the host engine or the online container.
Flutter retains HUD, gestures, existing cut/shuffle deck presentation, sound and
haptic ownership. The existing 3D toggle is available in LAN settings. Practice's
default remains Flutter; renderer startup/failure still leaves a playable fallback.

Host admission, TLS, authoritative engine, allowances, validation, scoring and
timers are unchanged. The replica labels its display revision with the accepted
room revision; the host state and transport payload are not rewritten. Unity card
input goes through the same replica intent and host validator. ACKs cannot play
a card or advance a turn.

Reconnect cancels cosmetic work, adopts the fresh private snapshot and resumes
without replaying missed effects. It reuses the existing view. Native UaaL retains
its engine across platform-view disposal, so a new controller sends optional
REQUEST_READY. The upgraded Unity bridge clears old card objects/generation state
and repeats the existing explicit READY/capability handshake. Legacy cold-start
messages are retained, and disposed callbacks are ignored.

Portrait review found a genuine camera/anchor resize race. The optional
UNITY_VIEWPORT_CHANGED signal reconciles the current visual snapshot after Unity
has observed new Screen dimensions. This is presentation-only: no delays,
authoritative changes or new rules are introduced.

## Evidence

- Final full Flutter suite with the three existing release gesture flags:
  **712 passed** (`build/lan-unity-2026-10-28/flutter-final-full.log`).
- LAN Unity integration test exercises scoped readiness/privacy, real board
  subscriptions, rejected intent forwarding, reconnect without replay, stale ACK,
  subsequent actions, viewport reconciliation, 2D/3D preference switching, sticky
  renderer failure and disposed callbacks. No Firebase application is initialized.
- Default-flag focused run: **15 passed**. Resize/renderer focused run:
  **16 passed**, followed by the final expanded LAN regression and full suite.
- Scoped analyzer: no errors or warnings; 17 existing style/deprecation infos in
  settings_overlay.dart, whose only change is the LAN 3D-toggle visibility guard.
- Connected Unity Editor compiled the extension. Temporary Play Mode passed
  **7 warm-remount checks** and the existing **13 card-feel checks**. Observed
  gesture contact about 273ms, refined contact about 275ms and total settle about
  486ms. No scene was saved; these are PC renderer checks, not phone timings.
- Fresh Android Unity export: succeeded, **zero errors**, three warnings, 40.83s.
- Fresh iOS Unity export: succeeded, **zero errors**, two warnings, 61.12s.
  Windows cannot compile the resulting project using Xcode.
- Initial WebGL player export returned BuildResult.Succeeded but recorded two
  automation transport/watchdog errors during the long build. Its original
  report is retained as web-export-first.json. Subsequent exports are scheduled
  outside the request so transport watchdog errors cannot pollute their reports.

Native warnings concern the disabled runtime automation package, the existing
Android ndkPath template upgrade and an unused debug-console field. No packages,
Gradle/AGP/Kotlin/JDK versions, scene, approved animation timings or audio choices
were changed. Unity's automatic template edit was restored from the hash-verified
pre-export backup. All protected scene/settings/template hashes match; the Editor
is stopped, not compiling, scene clean and target restored to WebGL.

## Final artifacts and responsive result

The corrected final WebGL export succeeded with **zero errors**, two warnings,
499.70s. Its complete report is web-export.json; the initial timed-out export
report remains separate. The fresh player files in both ignored Flutter build
outputs match the hashes in web-player-hashes.json.

Android normal-entry debug APK:
`build/lan-unity-2026-10-28/halabessa-lan-unity-arm64-debug.apk`,
287,433,164 bytes, SHA256
`ea22a01873d85baa129ecacacd9337a54310b41cfe8b65936eba226a5e54b435`.
Build passed (409 Gradle tasks). Verification passed one MainActivity launcher,
ARM64 only, min SDK 24 / target 36, debug signature and ZIP/ELF 16 KB alignment.
Packaged metadata exactly matches the fresh export and contains REQUEST_READY,
UNITY_VIEWPORT_CHANGED and the existing visual/interaction capability markers.
Android metadata SHA256:
`11434fd98d2d2dc96d7efe3c6f94da3ffbd3d1ba10aec720721f527fda4b27e5`.
iOS metadata SHA256:
`173678c391f30aade85b41aafafec9d51ab9e3749ce863936e6ad4db4b45f84a`.

The final real Unity WebGL player was reviewed through the memory-only LAN
fixture at 390x844 and 850x390. Portrait-to-landscape-to-portrait now keeps all
four hand cards aligned and inside the table. The queued swipe-up pose was also
observed on the Unity hand without a gold border. Images are preserved as
unity-landscape-final.png, unity-portrait-final.png and
unity-portrait-after-rotation.png in the same ignored build folder. The older
unity-queued-swipe.png records the verified queue pose before the resize fix.
Arabic portrait was also reviewed with the real renderer; physical player seats
remain consistent, and the existing 3D setting is visible in the LAN settings
sheet. Its screenshot is unity-portrait-ar-final.png.

Final Flutter review bundle: main.ddf1954c002d6339.dart.js and
flutter_bootstrap.2c98420287b09da7.js. Final production web bundle:
main.a793b100eb850ec2.dart.js and flutter_bootstrap.d7fffbd5ef3d1c0e.js.
Unity-generated template backup files were retained under the ignored
generated-template-backup recovery folder rather than left as source assets.

## Remaining verification / release gates

Physical Android/iPhone LAN, native compositing, permissions, QR scan, reconnect,
audio and haptics remain outstanding until devices are available. This work does
not qualify a physical full match or mixed-platform Wi-Fi network. ADB detected
no attached phone at final verification; Xcode/iPhone is unavailable on this PC.

Generated players remain isolated under build/lan-unity-2026-10-28. Existing
tracked embedded Android/iOS libraries are preserved. A future approved native
release must package the fresh Unity player rather than an older embedded export.
The test APK uses the prior ignored QA gesture defines; native release defaults
are unchanged. Product LAN remains mobile-only.

The local browser review uses simulated room data with a real Unity renderer,
not a real LAN listener or joinable QR. Port 9121 serves the final explicit review
entrypoint; renderer=unity opts it into the scoped view. No production account,
real opponent private hand or invitation is used in screenshots/logs.
