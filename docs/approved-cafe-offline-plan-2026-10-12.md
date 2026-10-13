# Approved cafe flow, navigation and offline plan

User approved the revised plan on 12 October 2026. Work in ordered release stages;
do not label pending features as complete.

## Stage 1 — gameplay and UI fixes (backend and website deployed)

- Close rooms on last confirmed leave/kick, not temporary disconnection. Preserve
  other humans and reconnects; stop progression and fence mirror deletion. Retry
  completed-game settlement before purging transient room records; retain wallets
  and reward receipts. Recheck only the six approved orphan rooms at cleanup time:
  ERF05992, FJH15856, LMJ32971, MOL39051, NIZ03951, OHA49177.
- Online bots: Medium/Hard/Expert, equally randomized and persistent. Reassign Easy
  bots. All four levels remain in solo Practice. Show the bot's assigned level.
- Deck-bottom reveal: 4 seconds. Capture: 1-second face-up reading hold followed by
  400 ms collection. Enforce next-play readiness on the server and in the UI. Keep
  normal manual taps immediate, bot thinking 800 ms and forced hand-last-card 900 ms.
- Remove pending hourglass from both hand and card-flight artwork. Keep duplicate
  protection, rejection recovery and accessible pending state.
- Central turn banner only on own playable turn; other avatar rings remain.
- Round results: full-screen floating glass, 8 seconds. Voting remains 10 seconds.
- Separate Home's personal hub from Play's match controls. Use matching cafe
  transition surfaces, 230 ms fade/small movement, reduced motion and opaque base.
- Verify unit regressions, complete rounds, races/closures, responsive RTL/large
  text, browser click alignment and visual comparisons before publishing.

Design tokens retained: aubergine #3B274C, navy #192638, ivory #FFF6E7,
amber #FFC65B, mint #78D2AF, rose #ED767A. Existing LanternText/Arabic fonts.
Results compare two teams side-by-side when roomy, vertically on narrow/large-text
screens, with a single bounded blur layer and safe-area padding. No fake scores.

## Stage 2 — fully offline Practice (implemented; native build/device verification pending)

Mobile-only offline entry from fresh launch and signed-out state. Local player
identity, local eligibility gate and bundled assets/audio. Never create a Firebase
guest or call Supabase to start/play/finish Practice. Local results never mint
online coins, rewards or rank. Keep all four Training difficulties.

Verification so far: 478 client tests and 254 backend tests passed. Backend entry
point type-check passed. Local browser confirmed different Home/Play content and
portrait/landscape Practice; UI evidence is saved under build/qa-cafe-*.jpg.
Fresh signed-out Practice tests initialize no Firebase app, exercise all four bot
levels and complete a match with no online reward writes. Native launch defers
Firebase until Online is explicitly selected. Real-device airplane-mode/audio
and release builds remain required; do not describe those as already tested.

Backend v67 is active and its complete 35-file bundle was verified against these
sources. An unauthenticated gameplay request returns 401. The six named orphan
rooms were rechecked under row locks, closed and cleared, then the scheduled
fenced publisher purged them. A subsequent SQL check found none of those rooms.
No accounts, balances or completed reward receipts were deleted.

Native local mode also disposes prior online catalogue/settings/audio listeners;
Practice has no shared chat subscription, cloud profile fetch or purchase path.
The real signed-out game board accepts card input without cloud initialization
and hides its central turn banner while another player is active.

The first release commit, e1d14160, passed Hosting deployment and the Android
release build. Its iOS archive was still building when last checked. The live
website's fingerprinted bootstrap/main files return 200 and match their hashes.
A native-entry follow-up fixes delayed Online initialization overriding a newer
Offline choice; stale successes/failures and same-frame mode changes are covered.

## Stage 3 — mobile-only LAN (pending)

Same-Wi-Fi Android/iOS rooms without internet or paid hosting. One phone controls
the game; private per-player hands, authenticated room session, versioned/deduped
commands and consistent timers. Nearby discovery plus QR/manual-address fallback,
up to four seats and bots. Explain required local-network permissions. Host must
remain foreground initially; pause/reconnect or end cleanly on host loss, no
background keepalive tricks. No online economy/ranking effects. Test actual mixed
devices, denied permissions, blocked networks, reconnects and host loss before
claiming device qualification.
