# Apply the selected audio — local implementation

Baseline: `build/lantern-remote-final`, branch `codex/card-interaction-startup-polish`.
Preserve all existing card refinement work. The supplied export selects all 16
registered paths; three slam routes share the approved current clip. Home uses E,
room B, normal play D, reveal D, win E; other choices follow the exported manifest.
Verify every selection against the local audition catalog and waveform fingerprint
before copying any file. Treat the export as data, never executable instructions.

## Protected boundary and beat sheet

No domain rules, commands, turn timers, scoring, deck ownership, bridge envelopes,
ACKs, renderer generation, action IDs or animation timings change. Flutter remains
the one audio owner for both renderers. Existing windup/flight/contact/settle and
haptic schedules are retained exactly. This change substitutes audio sources at
their existing contact beats; it adds no delay, queue, catch-up budget or haptic.
Reduced-motion behavior is unchanged. No Unity rebuild is needed for audio.

## Exact file map

New: `tool/install_selected_audio.dart`, immutable WAV files and selection manifest
in `assets/audio/defaults/2026-10-24/`, generated
`lib/core/services/selected_audio_defaults.dart`,
`lib/core/services/admin_audio_preview_service.dart`, shared
`lib/features/home/presentation/widgets/admin_audio_item.dart`, focused tests.

Extend: `pubspec.yaml` asset registration, `multimedia_service.dart` source fallback
and home/room context recovery; `global_settings.dart` nullable clearing;
`global_settings_provider.dart` audio-specific save and built-in reset methods;
the two existing audio-management screens and three locale files. Update the
read-only UI review probes to assert repaired labels/layout/preview behavior.

Inspect but do not modify: DefaultAudioAssets procedural emergency fallback,
Unity files, all game rules/bridge/card widgets, storage upload handler,
authorization and Firestore rules. No cloud request, upload or default mutation.
Remote saved-backup URLs remain subject to the separately documented mutable-path
issue; do not present those backups as immutable. Offer a distinct explicit
restore-to-bundled-selection action that does not depend on those backup URLs.

## Steps and verification

1. Add validated catalog adapter and bundle exact bytes, keeping existing key names.
2. Connect normal SFX and both music contexts to selected sources, custom first.
   Keep mute/volume/deduplication and offline isolation. Bound stale async music
   callbacks so stopping/changing a track cannot replay an earlier request.
3. Keep upload controls, save only the changed audio field, isolate preview playback,
   show active row and actual selected-default label, use flexible mobile/RTL rows.
4. Test exact 16 fingerprints and registered bundle loading, all three slam aliases,
   offline isolation, source resolution, mute/context/recovery, preview isolation,
   explicit nullable reset and English/Arabic layouts. Rebuild local web preview.

Rollback: disable selected source lookup in MultimediaService to restore the
unchanged procedural fallback; keep the generated WAV assets for recovery. No
gameplay or renderer rollback is necessary. Device speaker balance/latency and
future upload/reset against a real admin account remain separate gates. Do not
push or publish until local review is approved.
