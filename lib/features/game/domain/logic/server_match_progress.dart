import '../models/match_state.dart';
import 'match_presentation_timing.dart';

/// Scheduling is only a request hint: the server independently checks its clock.
bool serverProgressDue(MatchState s, DateTime now) {
  if (s.roomClosed || !s.usesServerCommands || s.playerIds.length != 4) return false;
  if (s.phase == GamePhase.playing && s.playAvailableAt != null && now.isBefore(s.playAvailableAt!)) return false;
  final phaseStart = s.phaseStartedAt ?? s.turnStartTime;
  bool elapsed(int milliseconds) => phaseStart != null &&
      now.difference(phaseStart).inMilliseconds >= milliseconds;
  switch (s.phase) {
    case GamePhase.waitingForPlayers:
      return !s.playerIds.any((id) => id.startsWith('waiting_'));
    case GamePhase.preRoundCut:
      final cutter = s.playerIds[(s.dealerIndex + 3) % 4];
      return elapsed(cutter.startsWith('bot_') ? 1000 :
          (s.timerDurationSeconds > 0 ? s.timerDurationSeconds : 15) * 1000);
    case GamePhase.dealingFasha:
      return elapsed(deckRevealDuration.inMilliseconds);
    case GamePhase.dealingCards:
      return elapsed(5000);
    case GamePhase.roundScoring:
      return elapsed(roundResultsDuration.inMilliseconds);
    case GamePhase.capturing:
      return elapsed(captureTotalDuration.inMilliseconds);
    case GamePhase.playing:
      if (s.areAllHandsEmpty) return true;
      if (s.turnStartTime == null) return false;
      final active = s.playerIds[s.currentTurnIndex];
      if (s.handCounts[active] == 1 || s.handCards[active]?.length == 1) {
        return now.difference(s.turnStartTime!) >= lastCardAutoPlayDuration;
      }
      final bot = s.playerIds[s.currentTurnIndex].startsWith('bot_');
      if (!bot && s.timerDurationSeconds <= 0) return false;
      return now.difference(s.turnStartTime!).inMilliseconds >=
          (bot ? botThinkDuration.inMilliseconds : s.timerDurationSeconds * 1000);
    case GamePhase.shuffleVoting:
    case GamePhase.rematchVoting:
      final votes = s.phase == GamePhase.rematchVoting ? s.rematchVotes : s.shuffleVotes;
      final humans = s.playerIds.where((id) => !id.startsWith('bot_') && !id.startsWith('waiting_')).toList();
      return elapsed(10000) || (humans.isNotEmpty && humans.every(votes.containsKey));
    case GamePhase.matchOver:
      return false;
  }
}

/// Never let delayed intent responses roll back a newer room revision.
bool canAdoptServerSnapshot(MatchState? current, MatchState incoming) =>
    current != null && current.usesServerCommands && incoming.usesServerCommands &&
    current.id == incoming.id && (incoming.serverVersion > current.serverVersion ||
      // An initial public create/reconnect snapshot may still need its own hand.
      (incoming.serverVersion == current.serverVersion &&
        current.handCards.isEmpty && incoming.handCards.isNotEmpty));
