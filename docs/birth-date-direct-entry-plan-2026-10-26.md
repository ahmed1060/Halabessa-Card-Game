# Birth date and direct game entry

User approved storing a birth date in the private player profile, prompting guests
after Continue as guest, requiring existing registered players to add a missing
date on their next sign-in, and removing the pictured marketing landing page.
Work remains local on development; the separate UTF-8 fix and native qualification
are preserved. No additional publication is assumed.

Use the existing owner-private Firestore users document for dateOfBirth, stored
as a UTC date-only timestamp. Keep it outside AppUser/public projections and the
legacy RTDB mirror. Existing account deletion removes that document. Restrict
client writes to valid dates at least 13 years ago; retain account deletion and
policy access even when onboarding is incomplete. Offline Practice remains
cloud-isolated and asks its local eligibility question after Practice is chosen.

Signed-out visitors reach the existing sign-in screen. After authentication,
missing birthdays open a themed completion form before Home or protected deep
links. Existing dates remain editable from the owner's profile. Preserve the
blocked-age decision, guest-to-account linking, loading beat and all game rules,
turns, scores, animations, audio choices and Unity bridge contracts.

Exact changes: new auth data birth_date_store.dart, presentation providers
birth_date_providers.dart and widgets/profile_birth_date.dart; extend auth_wrapper,
profile_screen, app_routes, main, native_play_entry, age_eligibility_screen and age_eligibility_provider.
Extend firestore.rules, translations and privacy copy. Update web/index.html and
scripts/version-web-build.mjs so index.html and play.html run the same game;
remove unused landing HTML/CSS/route script after checking references. Preserve
canonical metadata, aliases, sitemap, verification file, query/hash routing and
a truthful JavaScript-disabled fallback. No invisible search-only content.

Reuse existing UI transitions; the birthday form itself adds no animation,
gameplay delay, bridge event or haptic. Date picker and scrolling use standard
Flutter behavior, including reduced motion and accessibility settings.

Verify real UTF-8 timestamp round trips, exact 13-year/leap boundaries, save
failure/retry and session switching, guest/existing-account gating, protected
deep links, public-field exclusion, Firestore owner/other-account permissions,
offline zero-cloud behavior, English/Arabic narrow screens, root/legacy web
entrypoints and the full regression suites. Local fixtures only for date writes;
never invent a live person's birthday or alter their saved profile for testing.

Rollback is this scoped unreleased patch. Existing profiles need no migration;
missing dates are collected during onboarding. No new backend project or schema
is introduced.

The existing blocked-age decision is enforced after authentication on protected routes. Sign-out, policies and account deletion remain accessible from that boundary; missing birthdays never expose Home/game first. Native offline eligibility still follows choosing Practice and initializes no cloud service.

## Local verification

- Full Flutter suite with web release gesture flags: 689 passed. Final default-mode suite: 686 passed, 3 feature-flag cases skipped. The final focused onboarding/offline suite passed 33 tests.
- Backend suite: 298 passed. Isolated demo Firebase rules suite: 48 passed, including owner-only birthday access, UTC date validation, exact age boundary, retained stats and denied field removal.
- Birth date data/providers/widgets and the review target passed scoped analysis with no issues. Production and memory-only review web builds succeeded; the production artifact is rebuilt after the confirmed-save guard.
- Browser review at 1280x720 English, 320x568 Arabic and 850x390 Arabic: form fits and scrolls; empty selection disables Save; the real picker accepts a leap-day test date; saving opens the profile field; its editor reopens with that date. Browser sizing was restored afterward.
- Screenshots and logs are under ignored build/birth-date-2026-10-26 and build/table-social-ui-2026-10-25. The review target tool/birth_date_review.dart initializes no Firebase and keeps its sample date in memory only. No live person's birthday was entered or changed.
- Root and play.html share the same fingerprinted code; root retains canonical/social metadata, aliases, verification, sitemap and a truthful noscript fallback. Existing play/hash/query links remain valid.

The final normal production build was opened at the local root URL and reached the real sign-in/guest screen directly, with no landing page or pre-auth date prompt. No guest account was created during that read-only check. Its main bundle is main.b390b2d534bbc7df.dart.js and its bootstrap is flutter_bootstrap.56a4c2aa563d13a7.js. The separate memory-only visual fixture remains available on loopback port 9117; it is never a deployment entrypoint.

The private stream ignores unacknowledged local writes and subscribes to metadata changes, so onboarding does not unlock from an optimistic write that the server may reject. No AppUser serialization or public profile shape was expanded.

New work remains uncommitted on development and unpublished. Release must deploy the birthday Firestore rules with the web change. The independent UTF-8 client/header correction is also local; it must be released before saving previously garbled live Arabic catalog text. Native device installation, haptics/audio and Xcode/iPhone checks remain separate from these browser/emulator results.
