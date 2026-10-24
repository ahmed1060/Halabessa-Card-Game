# Full sound selection and existing admin UI review

Scope approved by user: offer alternatives for all game audio, later make chosen
audio the bundled defaults while retaining future changes through the existing UI,
and review that UI. No new default is inferred before the user chooses it.

Active checkout: build/lantern-remote-final, codex/card-interaction-startup-polish.
Preserve the existing dirty card-refinement work and all unrelated changes.

## Deliver this turn

Inventory 14 configured SFX paths (12 event families; slam has three routing
paths) and two music paths. Following the request for more options, produce current
plus five candidates (A–E) for each family/track: 84 clips total. Preserve all 42
original Current/A/B files byte-for-byte and retain the same browser selection key.
Current slam is the already-approved dry paper edge
A, which stays selected by default. No synthesized sound is described as recorded
Foley or a real instrument. Music options are short procedural loop sketches.

Create a standalone, loopback-only audition page. It keeps one audio element,
starts only after an explicit user click, stops on page hide, has a volume control,
native radios per event, local-only persistence and a JSON selection export.
Selecting/exporting is not publication or a game-default change.

Render the actual existing Flutter SFX/music management screens using fake local
providers. No Firebase initialization, upload, live settings writes or account
creation. Test current behavior and record findings without silently fixing the
production UI under review-only authorization.

## Design

Lantern sound table: aubergine #301728, ink #192638, ivory #FFF6E7, brass #FFC65B,
mint #78D2AF and coral #ED767A. Georgia display heading, Segoe UI controls; no
external fonts/assets. A quiet mixing-desk layout, not a game-screen redesign.
One sticky listening strip and event rows; left-aligned text and three choices
per row in two rows on desktop, vertically stacked on phones.

    Halabessa sound table    [volume] [stop] [export]
    Event / when heard      Current       A            B
    Card played             play/choose   play/choose  play/choose
                            C             D            E
                            play/choose   play/choose  play/choose

The repeated structure is necessary for exact per-event comparison, not decoration.
Native buttons/radios, labels, visible focus and 44 px targets. Audio descriptions
are the accessible alternative for these non-speech clips. No autoplay, motion,
tracking, remote library, network upload or production controls.

## File map and protected boundary

New: tool/export_game_sound_options.dart; tool/sound_review/index.html,
app.js, styles.css; tool/serve_sound_review.dart; test/admin_audio_review_test.dart;
docs/audio-admin-review-2026-10-24.md. Generated WAV/JSON/screenshots live under
ignored build/sound-options-2026-10-24/.

Inspect, do not modify: default_audio_assets.dart, multimedia_service.dart,
global_settings_provider.dart/global_settings.dart, settings_overlay.dart,
admin_sfx_management_screen.dart, admin_music_management_screen.dart, app_routes.dart,
trusted upload handler and Firestore rules. No rules, turns, scoring, bridge,
action timing, haptic profiles, audio routing, production build flags or shipping
exports change. No push/deploy/live mutation.

## Audio and future implementation contract

Current game event timing and single Flutter audio owner remain unchanged. New
samples are review files only. Candidate effects span 40–800 ms by event; music
sketches are 12-second loops. Peak limiting/fades prevent digital clipping; these
checks do not certify perceived quality or physical-device latency.

After selection, propose a small bundled catalog adapter using existing asset keys.
Desired resolution: custom override -> chosen published default -> bundled factory
default. Save-default copies must use immutable/versioned objects so replacing a
custom sound cannot overwrite its backup. Separate factory reset from saved-default
restore. Local offline mode must keep its cloud-isolation policy; discuss downloaded
override caching explicitly instead of reading live settings offline.

Retain legacy routing keys, contact deduplication, mute/volume and one audio owner.
Preview controls should have isolated playback state, not affect a live match or
music context, and never make a preview selection an implicit global save.

## Acceptance

Verify every registered slot is represented; 84 valid local PCM files, sane peak
and ending energy, no zero/NaN audio. Compare selected slam bytes with the approved
sample. Test existing UI at narrow portrait/landscape, Arabic/English, fresh/custom/
saved-default states, correct per-row playback and reset/fallback semantics.
Browser-check selection persistence, single-player playback, volume, export and
small-screen overflow. Native speaker/haptic tests remain a separate device gate.
User choices and authorization are required before changing production defaults,
storage policy, administration or publishing.
