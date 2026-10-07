import 'match_state.dart';

/// Public awards recorded by the engine, not inferred from hidden cards.
class RoundScoreBreakdown {
  final int captures, tafweetBonus, majorityBonus;
  const RoundScoreBreakdown(
    this.captures,
    this.tafweetBonus,
    this.majorityBonus,
  );
  int get total => captures + tafweetBonus + majorityBonus;

  static RoundScoreBreakdown? forTeam(MatchState state, String team) {
    if (!['teamA', 'teamB'].contains(team) ||
        ![
          GamePhase.roundScoring,
          GamePhase.shuffleVoting,
          GamePhase.rematchVoting,
          GamePhase.matchOver,
        ].contains(state.phase))
      return null;
    final captures = (state.harvestStacks[team] ?? [])
        .where((c) => !c.isRoundAward)
        .toList();
    if (captures.any((c) => c.awardedPoints == null)) return null;
    int cards(String id) =>
        (state.harvestStacks[id] ?? []).fold(0, (n, c) => n + c.cardCount);
    final own = cards(team), other = cards(team == 'teamA' ? 'teamB' : 'teamA');
    if (own + other != 52) return null;
    return RoundScoreBreakdown(
      captures.length,
      captures.fold(0, (n, c) => n + c.awardedPoints! - 1),
      own > other ? 3 : 0,
    );
  }
}
