import '../../domain/models/match_state.dart';

class ScoreConfig {
  static const int normalCapture = 1;
  static const int majorityCapture = 3; // Al-Ard

  // Exclusive to Tafweet Mode
  static const int normalTafweet = 10;
  static const int fashaTafweet = 20;
  static const int doubleTafweet = 30;

  /// Calculates Tafweet bonus if applicable.
  /// Returns 0 if not a Tafweet capture.
  static int calculateTafweetBonus({
    required GameMode mode,
    required bool isImmediateRecapture, // true if player captures card thrown immediately by opponent before.
    required bool isFashaActive, // true if capturing from initial 4 center cards
    required int consecutiveTafweets, // Used to trigger Double Tafweet
  }) {
    if (mode != GameMode.tafweet) return 0;

    if (consecutiveTafweets > 0 && isImmediateRecapture) {
      return doubleTafweet;
    }

    if (isFashaActive && isImmediateRecapture) {
      return fashaTafweet;
    }

    if (isImmediateRecapture) {
      return normalTafweet;
    }

    return 0;
  }
}
