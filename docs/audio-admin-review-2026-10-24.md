# Audio choices and existing admin UI review — local only

## Delivered

The loopback audition page at http://127.0.0.1:9114/ has 14 event groups covering
all 16 configured audio paths: 12 effect families (slam has three routing paths)
and two music tracks. Every group offers Current and A–E: 84 WAV clips total.
C/D/E add 42 clips; all original Current/A/B clip fingerprints are unchanged.
The existing browser selection key is retained, so adding choices does not reset
the user's selections. Current slam remains the previously approved dry paper
edge. These are procedural sketches, not recorded Foley or real instruments.

Choosing, playing and exporting are review-only operations. No game default,
cloud setting, upload, deployment or existing production UI was changed.

## Existing UI findings

1. **Saved-default restore can lose its original audio.** The trusted upload
   handler in `supabase/functions/halabessa-api/index.ts` uses a stable
   `audio/{kind}/{key}.{extension}` object path with upsert. The settings provider
   saves a backup URL, not a separate immutable object. Uploading another file to
   the same path can therefore change what both URLs play. Use versioned objects
   and a saved-default revision before promising reliable restore. This finding
   is based on source inspection; no live overwrite was attempted.
2. **Null overrides cannot reliably clear local music state.**
   `GlobalSettings.copyWith` uses `newValue ?? existingValue` for nullable music
   URLs. The snapshot listener cannot express clearing a previously populated
   value. Add explicit nullable-field clearing semantics and a regression test.
3. **An audio save writes unrelated settings.**
   `GlobalSettingsNotifier.updateSettings` also writes the loaded timer, target
   score and other audio overrides. Use an asset-specific patch to avoid stale
   editor values replacing concurrent changes.
4. **Fallback and music context need to be explicit.**
   `MultimediaService` waits when online music has no override; the local music
   path uses the same bundled ambience for home and room. Pending music rescue
   can call the home resolver even for room music. Resolve by typed context:
   custom override → selected saved default → bundled factory default, preserving
   the app's existing offline/no-cloud boundary. Add error fallback for failed
   remote audio decoding as well as missing URLs.
5. **Status labels misrepresent the bundled audio.** The actual SFX/music screens
   say “No Sound Set” when there is no remote override, even though bundled SFX
   are available. Show Built-in / Saved default / Custom / Unavailable. Separate
   factory reset from restore-saved-default; distinguish local preview from save.
6. **Preview state is shared across rows.** The SFX screen checks one global
   playing state, so multiple rows show Pause while one effect plays. Clicking a
   different row can stop the old sound instead of playing the requested one.
   Use an isolated preview player and active asset ID; label Stop accurately.
7. **Arabic custom/default rows overflow.** Real Flutter fixture renders record
   a 13 px overflow at 390 px width; the narrow 320 px fixture records 83 px and
   35 px overflows. Use flexible status wrapping and a less cramped action row.
   Add accessible names/tooltips for play, upload and reset controls.
8. **Route visibility and upload validation could be clearer.** Admin entries
   are hidden in ordinary settings, but the admin routes lack an independent
   UI guard. Backend upload and configuration writes still require admin
   authorization: this is not evidence of unrestricted writes. Add consistent
   route feedback, localized errors, decoded-audio validation and per-effect
   duration/volume guidance. Immutable uploads also avoid overwriting a working
   clip before its new configuration is successfully saved.

## Evidence and limits

`test/admin_audio_review_test.dart` uses local fake providers and renders the
actual management screens, not mockups. Its eight probes passed in this review;
they intentionally record the existing overflow and behavior defects rather than
claiming those defects are fixed. Fixtures include English/Arabic, fresh/custom/
saved-default states, 390 px portrait, 320 px portrait and 844 px landscape.

`tool/verify_game_sound_options.mjs` passes for all 84 clips: registered path
coverage, six distinct files per event, valid non-silent PCM, no digital clipping,
effect tail fades, music boundary continuity, approved slam fingerprint and
preservation of the original 42 files. These objective checks do not establish
perceived sound quality, real-speaker balance or mobile latency.

The expanded browser page visibly exposes 84 radio choices, one audio player and
all 14 previously selected groups. User choices were not altered for testing.
No phone/Mac installation or physical audio tests are claimed here.

## Proposed follow-up after selection

First fix immutable saved defaults, field-specific saves and nullable clearing.
Then wire the chosen files through the existing asset keys, repair context-aware
fallback and isolate admin previews. Finally improve labels, Arabic layout and
accessibility, and verify reset/replacement on web, Android and iOS. Do not change
gameplay rules, timing, bridge ownership or haptics as part of that audio work.
