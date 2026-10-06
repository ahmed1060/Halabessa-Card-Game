# Halabessa — approved mockup comparison and proposed completion plan

Status: visual implementation approved by the user on 5 October 2026. Functional additions listed under decisions remain separate. Prepared after the server-controlled web rollout.

## Outcome

The implementation shares the approved lantern-café identity, but it is not yet a faithful implementation of the complete mockup set. The main remaining work is consistent screen composition, gameplay proportions, reusable controls and panels, and responsive animation anchors. Several pictured features already work and should be restyled rather than rebuilt. Weekly rankings and separate chat channels are functional additions, not simply visual changes.

Evidence: all ten supplied local images were opened after removing the invalid leading slash from their Windows paths. The deployed lobby, table, store, settings and leaderboard were inspected; live results/replay were observed during rollout testing. Source review covered capture history, dealer seats, waiting room, scoring, profile, help, chat and recovery. This is not a claim that every screen has been physically tested on iOS and Android.

## Reference set and conflict resolution

Image directory: `C:/Users/ahmed.arafa/.codex/generated_images/01a0c2a4-f37b-7a30-b376-0acafa78a6af/`.

| Reference | Use this image |
| --- | --- |
| G1 | `exec-7874b742-2ca6-4c20-ba0a-20d5e87cf3b4.png` |
| G2 corrected | `exec-b276c32b-7a6f-4106-ae95-6fcf8dc44359.png` |
| G3 | `exec-a9e9f182-f08f-4fdb-a39e-bf98e6e76bf9.png` |
| G4 | `exec-4fb8c5cc-127d-4d73-8010-c2b6b6c33e8d.png` |
| G5 | `exec-75eb686c-55ae-441d-b9f7-e8a2925d235c.png` |
| G6 corrected | `exec-424df1cc-582f-4d4f-8406-625712cf25d9.png` |

Earlier variants contain conflicting capture instructions, a three-card history limit, or an incorrect Tafweet description. They are not additional requirements. The written rules take precedence: correct Arabic title **حلبسه**, rank-based capture rules as implemented by the engine, one shared team collection, and only the capture cards played by that team during the current round. Artwork text, sample balances, reward amounts and prices are illustrative, not authority to change the economy or rules.

## Gap inventory

| Area | Current evidence | Proposed completion |
| --- | --- | --- |
| Shared visual language | Café background, purple felt, mint/coral team colors and lantern art exist. Legacy Material sheets, tabs and controls remain across screens. | One component system for headers, ivory panels, navy controls, brass outlines, typography, spacing and selected states. Preserve readable contrast rather than applying decoration indiscriminately. |
| Table composition | Current desktop table has a large empty center and relatively small remote seats/cards. Controls and collection panels differ from mockup composition. | Rebalance header, opponents, central play area, collections, local hand and controls using explicit portrait and landscape layouts. Match reference proportions at the reference aspect ratio, then adapt safely to other screens. |
| Dealer deck | `DealerSeat` already places the deck beside the current remote dealer; the local dealer has a deck/count/label near their hand. | Refine size, offset and gold dealer badge consistently for all four seats. Do not duplicate the deck or fix it to one player. |
| Hidden hands and turn indication | Card backs, card counts and turn timing exist. | Match the fan silhouettes, spacing and readable timer treatment. Keep turn indication subtle; do not restore the disliked square around an active player. |
| Shared team stack/history | Face-down collected stack, count, face-up latest capture and current-round history exist. History has arrows, numbering and a latest marker; it excludes captured pile contents. | Refine stack depth, panel sizing, capture preview and ivory history composition. Preserve every applicable capture, not only the last three. |
| Playing/dealing/capture animation | Existing flights, deal identities and stack growth are implemented. | Audit and tune the sequence: seat/hand origin → table → capture gather → face-down team stack. Use one seat-coordinate mapping for both rendering and animation; verify RTL does not swap physical player origins. Queue accepted events without replaying or skipping them. Provide reduced-motion equivalents. |
| Lobby/navigation | Quick match, practice, create/join and links to friends/store/rankings/rewards exist. No mockup-style persistent main navigation dock; lobby header lacks the pictured XP treatment. | Build the approved welcome/header composition and responsive Home/Play/Collection/Leaderboard/Profile navigation. Keep match controls separate from main navigation. Reuse real profile XP; do not invent sample values. |
| Create/join/practice | Functional forms exist, but inline expansion/modals differ from the illustrated setup screens. | Restyle mode cards, room visibility, room code, validation and practice difficulty selection. Preserve Easy/Medium/Hard/Expert behavior and existing public-room recovery rules. |
| Waiting room | Four-player readiness and bot-fill controls exist. | Match seat cards, team grouping, invitation/code treatment and clear start readiness. Keep the first two human joiners on the same team. |
| Cut/vote/round transitions | Server phases and vote deadlines work; round scoring currently has a relatively simple phase message. | Give each phase a stable, readable presentation with the mockup's detailed round summary derived from real scoring data. Never keep stale cards visible as playable or advance the server to accommodate animation. Check whether the required score breakdown needs an explicit public server summary. |
| Match results/replay | Live test showed rewards, scores and the working Yes/No replay countdown. Visuals remain a simple purple results screen. | Add the ivory celebration panel, winning-team portraits, laurels and clear rewards/score hierarchy. Retain the fixed 10-second replay vote, missing human votes becoming No, and no meaningless bot replay vote. |
| Store/collection | Store/Inventory switch and four categories exist. Current grid and tabs differ from the mockup. Default-card store preview uses classic green artwork while gameplay renders lantern artwork for `default_card`. | Fix preview/render consistency using one item-to-art mapping; restyle featured items, owned/equipped states, grids and previews. Preserve consumables, ownership and real prices; do not remove an existing category simply because it is not pictured. |
| Profile/guest presentation | Stats, XP, achievements and account actions exist; account linking is supported in the auth repository. | Apply the illustrated profile layout and a clear guest/save-progress presentation using existing linking flows. Verify recovery/error states and guest-specific actions; do not treat sign-in availability as proven solely by new styling. |
| Leaderboard | Live view confirms podium, ranking rows and pinned current-user rank. Existing categories are Stars/Wins/Best Score. | Restyle podium/panels/rows to the reference. Weekly/All-time filters and reset countdown require real period-scoped ranking data; include only as a separately approved functional extension. |
| Friends | Friends/Requests/Search tabs exist. | Restyle search, invitation and player cards. Add pictured All/Online/Offline filtering only with a reliable presence source; define stale/offline handling rather than guessing status. |
| Chat | Existing room chat and quick messages are present. | Match message panel, player portraits and quick-message controls. Team/Public/Game channels would require server-enforced visibility and channel semantics; do not simulate privacy with client-only tabs. |
| Settings | Music/SFX volumes, haptics, reduced motion, language, theme, landscape toggle and 3D option exist. Landscape preference is already on by default. No general reset-to-defaults action found. | Restyle illustrated settings, mint switches and sliders; add safe reset for local preferences. Preserve existing extra options and explain orientation limitations on mobile web. |
| Daily rewards | Claim flow exists; mockup decoration alone does not establish a missing reward feature. | Include its panel in the component pass and verify claimed/available/loading/error states against real server status. Do not copy illustrative reward values. |
| Help | Existing help includes rank-based capture illustration and explanations of teams/history/dealer. | Match the pictured tabbed guide and clearer capture example. Use actual special-card and Tafweet rules, not the incorrect older suit-matching draft. |
| Loading/recovery | Branded recovery screen, retry/exit and bounded loading handling exist. | Match illustrated card-fan composition and distinguish loading, unavailable match, reconnecting and ended practice. Visual polish must not reintroduce the flashing loading loop. |

## Proposed implementation order — subject to approval

### G6 account, help and recovery scope clarification

The additional G6 image `exec-f7b4e981-3182-4896-b4cf-922196327b78.png` is included as a visual reference for these screens, not for its incorrect suit-based capture explanation or misspelled Arabic logo:

- Reconnecting screen with illustrated card fan, clear connection status, retry and return-to-lobby actions.
- Ended-practice state with distinct start-practice and lobby actions; do not present an ended room as still reconnecting.
- Tabbed illustrated help for game basics, capturing and team play, including a rules-correct capture example and reduced-motion presentation.
- Guest account page with save-progress/account-linking explanation and provider actions appropriate to the platform and actual configuration.
- Account settings, privacy and help/support entry points. Review existing routes/content before adding anything; this comparison does not establish that every destination is currently missing.
- Account-deletion confirmation with explicit consequences, cancel and a deliberate destructive confirmation. Determine the real data-retention/deletion behavior before promising that all information is permanently removed.
- Recoverable action-failure panel with an actionable retry and no false success state. Destructive requests must not be blindly repeated if their outcome is uncertain.

This is a screen-design scope clarification only. It does not authorize deleting users, QA fixtures or account data, or changing authentication permissions. Use **حلبسه** throughout and the corrected G6 capture rules.

1. **Lock references and baseline.** Register the six corrected mockups and a screen/state checklist. Capture current screenshots at consistent sizes. Agree which functional additions are in scope.
2. **Shared components and card-art consistency.** Establish theme tokens and reusable screen/panel/button/tab/card-preview components. Fix default store preview mismatch first. Review screenshots before expanding their use.
3. **Table and motion.** Complete portrait/landscape composition, all dealer positions, collection panels, hand readability, physical-seat/RTL mapping and accepted-event animation sequencing. Verify after each meaningful edit.
4. **Game-flow screens.** Waiting, setup, cut/vote, dealing, round summary, results and replay. Retain authoritative phase/deadline semantics and exactly-once rewards.
5. **Remaining game shell.** Lobby/navigation, profile, store/collection, leaderboard, rewards, social, settings, help and recovery. Preserve existing capabilities not pictured in the drafts.
6. **Optional functional extensions.** Weekly rankings, reliable online filters and separate chat channels, only after decisions below. These must have truthful backend behavior and privacy tests.
7. **Acceptance pass.** Compare every completed screen/state with its selected mockup. Present screenshots and unresolved differences before declaring the full refactor complete.

## Acceptance checklist

- Reference-sized screenshots match composition, hierarchy, artwork, colors, panel geometry and control placement, with documented intentional changes for correct rules/accessibility.
- Portrait and landscape work at small mobile sizes, iPhone 15 Pro Max class dimensions and desktop; native and mobile-web safe areas remain usable. No clipped hand, covered avatar, double header, or offset tap targets.
- Arabic RTL and English LTR both preserve physical seat order and animation origins; team identity is not inferred from visual text direction.
- Test every dealer seat; zero/full stacks; long names; all four bot difficulties; guest/authenticated states; loading, empty and error states.
- Reduced motion avoids excessive movement while still showing what happened. Buttons and cards remain usable through phase transitions and overlays.
- Capture history is current-round-only, contains only our team's leading capture cards, and resets at the proper round boundary.
- Replay retains its real 10-second deadline; no mockup-only UI blocks or silently changes a server phase.
- Widget/golden tests cover components, responsive layouts and RTL; backend regression tests protect gameplay boundaries. Real-device browser/native verification remains a required release gate, not something desktop screenshots prove.
- No paid service upgrade, cosmetic economy change, player-data reset or unrelated auth/security change is part of this visual plan.

## Decisions for review

Recommended scope: complete the visual/component refactor and existing-feature polish first. Decide separately whether to include **weekly rankings**, **presence-based friend filters**, and **separate chat channels** now or later. Clarify the audience of “Public” chat before implementing a channel: public-room participants versus a global lobby channel have different moderation and privacy implications.

There is no need to recreate shared stacks, dealer distribution, orientation preferences, inventory, podiums or basic help from scratch. They already exist. The frontend-design review guided consolidation around the approved lantern-café identity rather than introducing another design direction.

## Rollout checkpoint before this review

Server-controlled new online rooms are enabled by default. Production creation/start/play, public-seat recovery/rejoin and live results/replay were verified. QA room QFP39484's approved temporary win target was restored to 21 after replay testing. Latest Hosting run 37310611919 for commit 42abe5b4 succeeded. Local verification completed with 293 Flutter tests and 89 backend tests passing. Mobile CI status is separate from this UI review; physical-device acceptance is still required. QA fixtures have not been deleted and existing player data has not been reset.

## Implementation checkpoint — first batch, 5 October 2026

- Added reusable ivory `LanternPanel` for the approved illustrated panel treatment.
- Store and enlarged previews now use one requested-item artwork component. The default deck uses gameplay's vector lantern art; custom decks retain their own back/front/special-card/suit overrides rather than accidentally using the equipped deck.
- Renamed the free default deck to the existing translated Lantern Nights name. IDs, ownership, prices and balances are unchanged.
- Centered the store wordmark/title, moved currency chips out of the narrow app-bar title row, and applied brass category selection and mint/navy inventory selection.
- Restyled item/preview panels and corrected the coin symbol in the preview purchase label. The enlarged default preview no longer shows the unrelated legacy premium suit showcase.
- Added four regression tests. Full Flutter suite: 297 passed. Targeted changed-file analysis: no issues.
- Compared local Arabic store and enlarged preview screenshots with G4. Confirmed the old green default-back mismatch is fixed and the header is centered. Remaining: featured-deck composition, full navigation dock, inventory-specific layout, and responsive/physical-device acceptance. This batch is not a claim of pixel-identical store completion.
- Local proof images: `build/ui-store-stage1.jpg` and `build/ui-store-preview-stage1.jpg` (not committed assets).

Next: shared navigation/header/category composition, featured store presentation and the table/motion pass. No gameplay, account deletion, paid-service or backend-channel changes were made in this batch.

## Combined UI completion checkpoint — 6 October 2026

The approved visual/component pass is implemented as one publishing batch with the first local store commit. The frontend-design review kept the approved lantern-café palette and composition; it did not introduce a replacement theme. This is not a pixel-identical or app-store-ready certification.

- G1: explicit physical-seat portrait/landscape composition; hand below the arena; shared collection panels above the hand in portrait and alongside it in landscape. Compact landscape portraits and dealer-deck offsets were checked in the local browser. RTL does not reverse physical seat or animation anchors. Existing motion queue, gameplay deadlines and reduced-motion behavior remain in place.
- G2: five-destination navigation dock, actual XP treatment, four lobby actions, modal join flow, illustrated mode choices and shared four-difficulty practice selector.
- G3: public player portraits in the waiting room, ivory decision/phase panels, real public capture/card totals with explicitly cumulative match scores, winning-team portraits and ivory results presentation. Replay and shuffle policies are unchanged.
- G4: featured-deck carousel with actual ownership/equip/purchase actions, paired face/back owned collection tiles, shared profile/navigation presentation and compact leaderboard podium with readable selected categories.
- G5: navy/mint presentation for settings, rewards, social and chat. Confirmed reset changes only presentation preferences and preserves account, inventory and room values.
- G6: tabbed rules-correct interactive help, illustrated recovery fan, a distinct ended-practice restart state, guest Google/Facebook linking with pending/error guards, and truthful account-data/support information routes.
- Added regressions for navigation sizing/taps, guest linking pending/failure states, help interaction, terminal recovery, settings reset isolation, localized deadline labels and long profile names in both text directions at enlarged text sizes. Complete Flutter suite: 309 passed; authoritative backend suite: 89 passed. Analyzer reports no errors, with existing warning/info debt still present. UI translation keys are present in all three locales.
- Browser comparison/proof: `build/ui-table-landscape-final.jpg`, `build/ui-table-portrait-final.jpg`, `build/ui-help-final.jpg`, and `build/ui-store-portrait-stage2.jpg`. These are local QA artifacts, not shipped image assets. Desktop browser checks do not establish physical-device acceptance.

### Intentional differences and remaining release work

- Detailed per-round bonus rows require a public authoritative score breakdown. The UI displays only real available capture/card totals and cumulative scores, not fabricated mockup numbers.
- Weekly leaderboards, presence-based filters and private team/global chat channels remain excluded pending separate functional approval and backend semantics.
- No account-deletion confirmation is offered without an actual deletion API. Signing out is explicitly not deletion. A configured support destination and published privacy/legal policy remain release requirements; information screens are not substitutes for them. Google/Facebook guest linking uses existing flows; native provider success and Apple guest linking are not claimed by this visual work.
- Browser orientation follows the device/browser; native preference remains landscape by default. Small screens and enlarged text intentionally adapt composition instead of preserving unreadable reference proportions.
- Physical iPhone/Android testing, native authentication configuration, mobile CI/build acceptance and store-policy compliance are separate release gates. No player data or QA fixtures were deleted, no balances/prices changed, and no paid service was enabled.
