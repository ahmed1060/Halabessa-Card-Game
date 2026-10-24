# Selected audio applied locally — 24 October 2026

The supplied `halabessa-sound-choices.json` was validated against the audition
catalog. All 16 logical routes use the exact selected PCM bytes, packaged as 14
immutable, fingerprint-named WAV files. All three slam routes share the approved
dry paper-edge waveform. No cloud defaults were written and nothing was published.

| Event | Choice | Sound |
| --- | --- | --- |
| Pick | B | Crisp corner flick |
| Return | B | Soft paper brush |
| Play | D | Double paper tick |
| Deal | B | Two-stage slide |
| Reveal | D | Bright flip and tick |
| Slam (all three routes) | Current | Approved dry paper edge |
| Capture | B | Warm collection accent |
| Shuffle | Current | Existing bundled riffle |
| Cut | A | Two packet taps |
| Win | E | Quiet resolved chord |
| Lose | Current | Existing descending tone |
| Purchase/reward | A | Light coin tick |
| Home/lobby music | E | Still courtyard pad |
| Room music | B | Felt ambience |

## Runtime and UI

- Existing asset keys and event timing remain unchanged. Flutter still owns audio
  in both renderer modes; no Unity source or renderer export was rebuilt.
- Custom URL overrides retain priority online. Empty/reset overrides resolve to
  the chosen bundled sound, including distinct home/room tracks. Offline sessions
  use bundled sources without consulting remote override settings.
- Music interaction rescue and mute/re-enable retain the room/home context and
  loop choice. Old preparation requests are invalidated on stop/track change.
- Broken remote clips fall back to the selected bundle; mute/volume and existing
  contact deduplication remain in place.
- Admin previews now use a separate player, with one active row and a Stop control.
  They do not replace live room music or consume the match SFX player.
- Rows show the selected bundled default, custom upload, or saved remote status.
  Their action controls wrap without the old narrow Arabic overflow. Preview,
  replace and restore controls have localized accessible labels.
- Uploads save only the chosen audio field, not match timers or unrelated loaded
  settings. Explicit “Restore your selected bundled sound” removes only the active
  override and does not rely on a cloud backup URL. Nullable music reset now clears
  correctly when the remote settings snapshot removes an override.

## Verification

- Full Flutter suite with the existing local refinement flags: **647 passed**.
- Focused audio/admin/legacy-fallback tests: **20 passed**; scoped static analysis
  reported no issues. Exact bundle loading/fingerprints, source precedence,
  offline isolation, mute/context recovery, stale music preparation, fallback,
  preview isolation and explicit restore were covered.
- Actual admin fixture renders: English/Arabic, 390/320 px portrait and 844 px
  landscape. All six render cases report no framework/layout errors, including
  the formerly overflowing Arabic rows. Generated artifacts are in
  `build/selected-audio-review-2026-10-24/`; baseline review images were preserved.
- Separate web build succeeded in `build/selected-audio-web/`. Its optional Wasm
  dry-run reports existing dependency incompatibilities; the JavaScript build
  succeeded. The verified existing Unity WebGL player was copied only into this
  generated preview and its WASM SHA-256 matches the prior local preview.
- Browser play on 127.0.0.1:9115 requested the selected room B, pick B, cut A,
  deal B, play D, capture B and current shuffle fingerprint-named assets. No
  browser error/warning entries appeared in that Flutter smoke check.

## Review and remaining boundaries

Local preview:
`http://127.0.0.1:9115/play.html?renderer=unity&lang=en#/game`
or change `renderer=flutter` for comparison. The older 9113 preview and sound
selection page at 9114 were not replaced. No shipping web/native build changed.

At this initial integration stage, legacy saved remote backups still pointed at
mutable upload paths. The subsequent local source fix and emulator evidence are
documented in `audio-backup-completion-review-2026-10-24.md`. That fix is not
deployed. Built-in restore remains independent. No real admin upload/delete/save
was exercised against live services. Native phone speaker balance, latency and
installation checks remain unverified until the available phone is connected.

Rollback: build with `HALABESSA_SELECTED_AUDIO_DEFAULTS=false` to restore the
unchanged procedural fallback sources; retained custom overrides still work.
This rollback does not change game rules, card gestures or renderer behavior.
