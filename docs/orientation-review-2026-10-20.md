# Orientation and portrait UI review — 2026-10-20

## Scope and visual proposal

The requested portrait/rotation/settings review sheet is `orientation-review-2026-10-20.png`.
It uses the selected Cut C physical plum-felt/wood/gold direction, retains four
player identities, hand counts, dealer indication, a small distribution deck,
Capture B's combined counts, and an unobstructed central playfield.

Suggested polish: keep the local hand within comfortable thumb reach; align
capture/history/menu controls into one compact corner; reserve gold motion/glow
for interaction and the active avatar, not entire player-seat rectangles.
This generated image is a concept, not evidence that the new table artwork or
Capture B/Cut C controls are implemented in the running app.

## Implemented locally

- `lib/core/widgets/web_orientation_gate.dart`: root-level mobile-web guard
  above the game, Unity layer, routes, and dialogs. An orientation mismatch
  displays a full-view blur/scrim and rotation instructions. No dismiss action;
  pointer, focus and underlying accessibility are blocked. Matching dimensions
  remove it without replacing the app subtree. Desktop/native bypass it.
- `lib/core/widgets/orientation_settings_control.dart`: explicit portrait and
  landscape choices using the existing persisted per-user setting. A primary
  superadmin checkbox controls whether other players see that selector.
- `lib/core/providers/orientation_policy_provider.dart`: presentation-only
  visibility document `settings/orientation.showPlayerControl`; reads default
  to visible when the document is absent. While remote policy is loading or
  fails, non-owner controls remain hidden. Offline practice has a local default.
  Primary-admin ownership requires verified email plus the existing signed admin
  token claim; ordinary delegated admins do not own the checkbox or writer.
- `firestore.rules`: reserves this one presentation document's writes for the
  verified primary admin and permits only a boolean `showPlayerControl` field.
  No production rule deployment or policy write was performed.
- `lib/main.dart`, `lib/core/widgets/settings_overlay.dart`, and
  `tool/option_b_preview.dart`: minimal integration hooks. The preview-only
  `mobileWeb=1` query allows desktop viewport QA of the mobile gate.
- English, Egyptian Arabic, Saudi Arabic translations; two focused test files.

The checkbox hides the orientation selector, not the rotation requirement.
The selected direction remains per user; there is no newly introduced global
forced-orientation setting. Native orientation behavior is unchanged.
Online game state, deadlines, audio and networking continue behind the gate.
This does not promise a browser/OS orientation lock or pause an online match.

## Verification

- Final full Flutter regression suite (including the root text-style fix):
  **528 passed**.
- After the browser-discovered root-text-style fix: focused orientation/policy
  suite **10 passed**; the overlay now has its own transparent Material ancestor.
- Analysis of the five new source/test files: **no issues**. Wider integration
  file analysis has existing informational deprecations/style lints only.
- Three localization JSON files parse and contain the required orientation keys.
- Local web preview builds successfully; existing QA Unity build files restored
  into its output after the Flutter build.
- Browser viewport QA: 430×932 and 932×430; mismatch overlays entire game;
  clicking and Escape do not dismiss it; matching rotation restores the same
  cut phase/settings dialog. Both orientation selections tested through UI.
  Screenshot proof: `build/orientation-gate-portrait-2026-10-20.png`.
- Widget tests cover primary/delegated roles, checkbox visibility, unauthorized
  writes never reaching storage, native/desktop bypass, keyboard insets,
  blocked pointer input and Escape, and restoration after rotation.

### Remaining release gates

**Merge-time update (2026-10-20): the emulator gate below is now resolved.**
Using a short local Java socket/temp path fixed the Windows loopback failure.
All **36** Firestore/database emulator tests passed, including nine new
orientation allow/deny cases in `rules-tests/orientation.test.mjs`. They cover
the verified primary admin, delegated/non-admin/missing claims, invalid schema,
forged profile flags, deletion-blocked/anonymous sessions, and unchanged general
settings permissions. The standard `npm test` script now includes these tests,
so the existing main-branch CI runs them before any rules deployment.
Evidence: `build/merge-rules-short-temp.log`. No production writes occurred.
The real-device and real-account qualification limitations still apply.

The following paragraph records the earlier local-review blocker:

The isolated Firestore emulator could not start: the installed Java 21 runtime
fails creating its local selector/loopback socket, including after the Windows
selector compatibility retry. Thus server-rule enforcement is **not yet
emulator-verified**. Do not deploy it or claim production enforcement until
allow/deny tests run successfully. No real-phone Safari/Chrome check has been
performed (no device available). The primary-admin checkbox is tested with role
fixtures, not by signing into a real primary-admin account.

No game-rule, domain state, turn-timing, Unity command, or win-condition changes
were made for this request. Existing unrelated working-tree changes preserved.
No commit, push, deployment, or promotion.

## Local review

Normal preview: `http://127.0.0.1:9111/?renderer=unity#/game`.
Desktop mobile-gate QA: append `&mobileWeb=1` before the hash, then resize the
browser view to portrait/landscape. This QA query is only in the local preview
entry, not a production authentication or policy bypass.
