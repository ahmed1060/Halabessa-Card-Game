/// Presentation waits, not authority: online eligibility is checked by the
/// server independently. Keep these in sync with match_progress.ts.
const captureMergeDuration = Duration(milliseconds: 300);
const captureTotalDuration = Duration(milliseconds: 600);
// Short reading beats for automatic moves; manual taps remain immediate.
const lastCardAutoPlayDuration = Duration(milliseconds: 900);
const botThinkDuration = Duration(milliseconds: 800);
