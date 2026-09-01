import '../models/match_state.dart';

/// Single source of truth for Halabessa's scoring numbers. GameEngine and
/// GameNotifier (game_providers.dart's Al-Ard bonus) both read from this
/// instead of the inline literals they used to hard-code separately, which
/// had drifted apart from these very constants (this file previously
/// defined Tafweet bonuses of 10/20/30 that nothing ever read; the engine's
/// own inline values -- 5/5/10 -- are what's actually live today). The
/// numbers below match that live behavior; they're not a redesign.
class ScoreConfig {
  static const int normalCapture = 1;
  static const int majorityCapture = 3; // Al-Ard: awarded to whichever team captured more cards at round end.

  // Tafweet mode bonuses, added on top of normalCapture.
  static const int standardTafweet = 5;
  static const int fashaTafweet = 5;
  static const int doubleTafweet = 10;

  /// calculateTafweetBonus below is NOT called anywhere. GameEngine._playCard
  /// decides which of the three Tafweet bonuses applies from
  /// MatchState.skippedMatches (a per-player list of "rank:sourceId" keys
  /// accumulated as cards get skipped over), which this function's
  /// boolean-flag signature doesn't model -- isImmediateRecapture /
  /// isFashaActive / consecutiveTafweets aren't values the engine computes
  /// anywhere. Left in place as a documented, unused alternative rather than
  /// deleted, since reconciling the two models is a larger change than this
  /// pass's scope (unifying the *numbers*, not the branching logic).
  static int calculateTafweetBonus({
    required GameMode mode,
    required bool isImmediateRecapture,
    required bool isFashaActive,
    required int consecutiveTafweets,
  }) {
    if (mode != GameMode.tafweet) return 0;

    if (consecutiveTafweets > 0 && isImmediateRecapture) {
      return doubleTafweet;
    }

    if (isFashaActive && isImmediateRecapture) {
      return fashaTafweet;
    }

    if (isImmediateRecapture) {
      return standardTafweet;
    }

    return 0;
  }
}
