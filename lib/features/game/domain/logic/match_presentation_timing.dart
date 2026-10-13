/// Presentation waits, not authority: online eligibility is checked by the
/// server independently. Keep these in sync with match_progress.ts.
const captureMergeDuration = Duration(milliseconds: 1000);
const captureFlightDuration = Duration(milliseconds: 400);
const captureTotalDuration = Duration(milliseconds: 1400);
const deckRevealDuration = Duration(milliseconds: 4000);
const roundResultsDuration = Duration(milliseconds: 8000);
// Short reading beats for automatic moves; manual taps remain immediate.
const lastCardAutoPlayDuration = Duration(milliseconds: 900);
const botThinkDuration = Duration(milliseconds: 800);
