import '../models/match_state.dart';

/// Delayed actions belong to one turn, not merely to one player or room.
bool sameMatchTurn(MatchState a, MatchState b) =>
    a.id == b.id &&
    a.roundCount == b.roundCount &&
    a.handInRound == b.handInRound &&
    a.currentTurnIndex == b.currentTurnIndex &&
    a.turnStartTime == b.turnStartTime &&
    a.phase == b.phase;

/// Reward completion is a metadata patch, never a replay of a scoring snapshot.
MatchState? applyMatchRewards(
  MatchState? latest,
  MatchState completed,
  Map<String, int> stars,
  Map<String, int> coins,
) {
  if (latest == null ||
      latest.id != completed.id ||
      latest.roundCount != completed.roundCount ||
      !const [
        GamePhase.roundScoring,
        GamePhase.rematchVoting,
        GamePhase.matchOver,
      ].contains(latest.phase)) {
    return null;
  }
  return latest.copyWith(earnedStars: stars, earnedCoins: coins);
}
