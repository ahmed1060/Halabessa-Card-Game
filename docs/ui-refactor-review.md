# Gameplay and UI review

Reviewed 27 September 2026. This is a phased refactor, not a claim that every
screen has been redesigned or every device has been tested.

## Direction: an Egyptian card table, built for reading and playing

The cards are the focal point. Use restrained felt and brass, not neon glow,
photographic table trim, or competing floating panels. Preserve purchased
table skins and the optional 3D renderer; do not change rules or services.

### Tokens and typography

| Token | Hex | Role |
| --- | --- | --- |
| Felt | #123E35 | Quiet playing surface |
| Ink | #102923 | Solid controls and trays |
| Ivory | #F7F3E8 | Primary text and card contrast |
| Brass | #C5A567 | Turn/selection, not body text on white |
| Muted | #A9BBB2 | Secondary information on ink |
| Red | #B73B42 | Destructive actions and red suits |

Use the platform's Arabic-capable sans-serif for the first table slice;
do not rely on the unbundled Righteous/Outfit web fonts for critical controls.
Scores: 24px bold; actions/body: 14–16px; supporting labels: 12px minimum.
Later bundle appropriately licensed Arabic and Latin families for identical
native/web typography. Keep sentence case; don't letter-space Arabic.

### Layout concept

Center the physical table/cards; use directional start alignment for text.
Reserve space for each region instead of placing everything in one Stack.

```text
Portrait                       Short landscape
+------------------------+     +---------------------------------------+
| Our score / Their score|     | Labelled score / round / room          |
| Round / target / room  |     +-----------------------+---------------+
+------------------------+     |      Partner          | Turn prompt   |
|        Partner        |     | Opp.  Table  Opp.     | Your hand     |
| Opp.   Table    Opp.   |     |                       |               |
|                       |     +-----------------------+---------------+
+------------------------+     | Chat / reactions / settings / leave   |
| Turn prompt           |     +---------------------------------------+
| Your hand             |
| Chat / reactions / ...|
+------------------------+
```

Principles: stable geometry; explicit team and turn labels; all cards inside
the touchable region; one clear action per phase; text as well as color;
48px controls; reduced-motion support; no recurring modal interruptions.

Pre-build critique: a generic casino reskin would retain the actual problems.
Use the familiar four-seat arrangement and readable hand as the distinctive
feature. Keep decoration out of the center. Do not change a user's equipped
skin silently. Extract layout and input first, then apply the palette across
the remaining screens after verification.

## Findings and evidence

Live observation covered guest entry, bot-room recovery, cut/deal/play
transitions, and portrait gameplay. Source review covered the table and
components, home, room setup/join, authentication/onboarding, settings,
rewards/results, and representative store/profile/leaderboard sections.
Purchase, social-account authentication, native device behavior, and every
end-of-match branch have not been comprehensively exercised.

| Priority | Finding | Evidence / consequence |
| --- | --- | --- |
| P0, already fixed | Audio notifications recreated the match controller | `game_providers.dart` watched a ChangeNotifier in the controller factory; deployed lifecycle regression fix preserves state. Do not conflate this with cosmetic animation. |
| P1 | Hand clips below the viewport and misses ordinary taps | Original `fanned_hand_widget.dart` used bottom -45, IgnorePointer and parent pan recognition. |
| P1 | Sideways drags can play; queued cards use list index | Same widget's onPanEnd submits without an upward threshold; didUpdateWidget reuses selected index after hand changes. |
| P1 | Input not phase-gated | Board passed only currentTurnIndex as isMyTurn, including dealing/capture phases. Server validation is not a substitute for correct UI affordances. |
| P1 | Seats, harvest piles, toolbar and hand overlap | `game_board_screen.dart` uses independent absolute positions in a shared Stack. Live phone layout confirms crowded regions. |
| P1 | Scores don't identify teams | `_buildTopBar` shows teamA:teamB regardless of the viewer's team, without team labels. |
| P1 | Build methods trigger winning effects repeatedly | `_checkWinner` called from build plus a second confetti block inside OrientationBuilder. Trigger once on phase transition instead. |
| P1 | Onboarding interrupts recovered matches | Live refresh showed reward and username overlays underneath/around match recovery. Root persistence/route cause still needs a separate investigation. |
| P2 | Recovery is vague | Full-screen loader has one ambiguous Retry or Exit action; no explicit recovering/error/back states. |
| P2 | Captures grow across the table | Harvest widget has a non-scrolling horizontal list without a bounded parent width. Replace with summary and inspectable history. |
| P2 | Small unreadable HUD and color dependence | 8–11px labels, icon-only round/hand counts, neon team colors. |
| P2 | Competing gesture and animation systems | Parent pan + nested Draggable + hover scaling; independent looping/reveal/confetti animations. |
| P2 | GameBoardScreen mixes too many responsibilities | About 1,650 lines handle routing, audio, phase overlays, seats, actions and results. Extract presentation widgets without moving authority into UI. |
| P2 | Avatar geometry changes with active state | `player_avatar.dart` changes padding/border and always reserves 40px for messages. Names/chat have insufficient width constraints. |
| P2 | Results need responsive single ownership | Fixed 340px dialog, unscrollable Column, hard-coded XP width; board also owns a game-over panel. Small landscape/text scaling need regression tests. |
| P2 | Room mode selection immediately creates a room | `create_room_overlay.dart` combines choosing classic/tafweet with submission. Separate configuration, clear Create action and pending/error states. |
| P2 | Join flow uses generic auth errors | `join_room_overlay.dart`; empty code silently returns and ROOM CODE is hard-coded English. |
| P2 | Store and profile need long-text review | Store currency chips compete with AppBar title; fixed aspect grid can clip text. Profile display name is in an unbounded Row. Risks confirmed in structure, not yet reproduced on every device. |
| P2 | Leaderboard exposes raw errors without retry | Async error branch prints exception; category tabs are GestureDetectors, not semantic controls. |
| P2 | Typography is not portable | Theme names Righteous/Outfit but pubspec has no bundled font declarations. Arabic relies on platform fallback. |
| P2 | Accessibility is inconsistent | Icon-only actions, GestureDetector controls, no comprehensive reduced-motion/RTL/text-scale/keyboard suite. |
| P3 | Visible production debug action | Table toolbar exposes Unity console toggle to ordinary players. Remove from normal match controls. |

The visible table pile is not necessarily the complete set of capturable
cards under these rules. Do not redesign it into a different game's board
or reveal hidden opponent cards. Preserve server authority and privacy.

## Delivery sequence

1. **Table foundation and input:** extract responsive table frame, labelled
   score/status and compact seats; reserve the hand zone; repair tap/drag,
   stable queued selection, duplicate input and phase gating. Add widget tests.
2. **Phase clarity:** one phase presenter for lobby, cut, fasha, votes,
   scoring and rematch; stable recovery with explicit retry/back;
   compact capture summary with read-only history; single result surface.
3. **Entry and social:** home/navigation, unintrusive rewards, onboarding
   sequencing, room configuration/join validation and pending states,
   chat and profile previews. Keep Facebook visible as requested.
4. **Supporting screens:** settings, profile, store, leaderboard and daily
   rewards share tokens, responsive forms, semantic actions and safe errors.
5. **Release verification:** complete guest-with-bots match, human room,
   reconnect, rematch, RTL, text scaling, keyboard and real native devices.
   No store-acceptance guarantee follows from a web build.

## Verification gates

- 320/390px portrait, tablet, desktop and short landscape; no obstructed cards.
- Arabic RTL and English LTR; 1x and 2x text scaling; safe-area padding.
- Tap, Enter/Space and deliberate upward drag submit the exact card once.
- Horizontal drag, stale preselection and inactive phases cannot submit.
- Reorder/removal preserves or cancels queued selection by card identity.
- Reduced motion eliminates decorative hand animation; focus remains visible.
- Team B players see their own score first; spectators see neutral team names.
- Audio notifications never remount the match controller or reset its state.
- All Flutter tests and analysis pass before Hosting publishes the new bundle.
- Verify deployed browser behavior separately from CI; native build success
  does not prove native gameplay/accessibility correctness.
