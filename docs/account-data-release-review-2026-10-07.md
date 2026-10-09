# Account data and release gates — 7 October 2026

Publisher: WeirdPuzz. Public contact: weirdpuzz@gmail.com.
Initial countries confirmed by the publisher: Egypt, Saudi Arabia, USA, Canada.
The current audience is ages 13+ only, as subsequently confirmed by the user.
This is an engineering inventory, not a published privacy policy or legal opinion.

## Verified implementation inventory

| Store | Current records | Deletion requirement |
| --- | --- | --- |
| Firebase Authentication | Guest/provider UID, email/provider identity, credentials managed by Firebase | Reauthenticate; disable/revoke identity; remove account; Apple authorization revocation where applicable |
| Firestore users | Profile, email, username, avatar URL, wallets, inventory, achievements, all-time stats, current-week ranking | Remove owned profile and reservations; prevent recreation by an old token |
| Firestore usernames | Username-to-UID reservation | Delete only reservations owned by the verified UID |
| Firestore matchRewardReceipts | Hashed match receipt and fingerprint, settlement time | Preserve duplicate protection without restoring a deleted profile; define and disclose retention |
| Realtime Database | Profile mirror, public/private room state, hands, lobby index, user-match pointer, presence, chat | Remove private data and presence; anonymize attributable shared history; leave/bot takeover without deleting other players' data |
| Supabase private halabessa schema | Shadow profiles/rewards, social edges, invites, rooms, hidden decks/hands, command ledger | Transactional cleanup with room locks; handle rooms.owner_uid FK before deleting profile; remove attributable command payload/results |
| Supabase game-assets bucket | Public uploaded avatars; publisher-owned store/audio assets | Remove all of the user's avatar objects, not shared publisher assets |
| Device/browser | Sign-in session, preferences, cached assets | Sign out and clear user-specific local state without resetting another account |
| Operational services | Firebase/Supabase requests and logs | Confirm actual retention and recovery behavior; do not promise immediate backup/log erasure |

The former Firebase rules allowed authenticated users to read whole profiles,
including email. Deployed rules now restrict Firestore and RTDB profile reads
to their owner or a custom-claim admin. Rankings and friend search use an
allowlisted Edge API projection of names, avatars and statistics; email,
balances, inventory and social edges are omitted. Nested and malformed fields
are filtered too. Hosting, Android and iOS CI succeeded for ff4bfe4e; no existing
player data was deleted by the privacy change.

Private deletion jobs retain a user ID, receipt digest and ordered completion
state; Firebase tombstones also retain the ID to block already-issued sessions.
Temporary peer/room inventory and delivery outbox rows are discarded on successful
completion. These are security records, not anonymized data, and the public
notices explicitly disclose their retention without an invented deletion SLA.

## Deletion acceptance contract

1. Derive the only target from the verified Firebase token; reject arbitrary UID,
   admin/primary-owner deletion through the normal consumer flow, stale auth and
   missing explicit confirmation. Guest accounts must also have a route.
2. Record a durable private job BEFORE revoking identity. Repeated requests and
   retry workers must refer to the same job, never a different account.
3. Block old sessions at the Edge API and Firebase rules. Current JWT signature
   validation alone does not perform Firebase revocation/deletion checks.
4. Revoke Apple authorization where applicable; then disable/revoke Firebase
   identity before cross-service cleanup. Never report success after partial
   cleanup or replace a user's UID with another live account's UID.
5. Release occupied seats using authoritative leave semantics. Preserve ongoing
   matches for other players, lock against commands/settlement, anonymize shared
   references, then delete private data and user-owned avatar objects.
6. Run bounded, restartable cleanup stages. Persist their completion server-side;
   retry transport failures without granting the deleted session access again.
7. Delete Firebase identity and mark complete only after all stages succeed.
   Provide an accessible in-app confirmation/status flow and public web request
   route. A support email is not a substitute for tested in-app deletion.
8. Use only separately approved temporary QA users to test deletion; prove old
   tokens are rejected and unrelated users, balances and matches survive.

As of 9 October, this contract is integrated into the active Edge version 36
endpoint and private scheduled worker. Client commit 501a1b54 passed Hosting,
Android and iOS CI, deploying explicit confirmation, provider reauthentication
and receipt-based recovery. Read-only deployed Arabic desktop inspection passed;
the cream-panel contrast follow-up has 365 passing Flutter tests but needs its
own deployment/visual recheck. The isolated live worker completed all six
stages, but the authenticated submission path and native Apple/provider behavior
still need live acceptance. The UI must not claim instant deletion or that store
requirements are certified complete. See account-deletion-verification-2026-10-09.md.

## Current audience decision: ages 13+

The user confirmed a minimum age of 13 for this release. Under-13 participation
is not supported. A neutral device-local birthday check precedes the app's auth
stream and routes; only eligibility is retained, not a birthday. This is a
self-declaration gate and does not prove age, consent or compliance.
Review all four markets with qualified advice as needed. US COPPA is relevant
to child-directed under-13 services and knowing collection from under-13 users.
Google Families also imposes safeguards for children's social features.

Required engineering work to define and verify: neutral age/parent flow before
online account collection, minimization of public profile data, child restrictions
for photos/free-text chat/friend discovery, adult action where required, reporting
and blocking/moderation, parent access/deletion, SDK/provider suitability, defined
retention and store declarations. An age checkbox alone is not parental consent.
Offline training may be a lower-data option, but must not silently create an online
guest account or claim no network processing without verification.

References checked 7 October 2026:

- https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa
- https://support.google.com/googleplay/android-developer/answer/9893335?hl=en
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://support.google.com/googleplay/android-developer/answer/13327111?hl=en

## Native acceptance remains a gate

Windows tests cannot establish physical iPhone/Android behavior or Apple signing.
Before release: signed Android/iOS CI artifacts, correct OAuth/Apple/Facebook app
configuration, physical portrait/landscape/safe-area/touch/background testing,
provider success/cancel/conflict and guest-link UID continuity, account deletion,
accessible text sizing/reduced motion, accurate privacy/Data Safety labels and
publisher-controlled store accounts. Do not upgrade paid hosting for these tasks.
