import '../models/match_state.dart';

/// Scheduling is only a request hint: the server independently checks its clock.
bool serverProgressDue(MatchState s, DateTime now) {
  if (!s.usesServerCommands || s.playerIds.length != 4) return false;
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
      return true;
    case GamePhase.dealingCards:
    case GamePhase.roundScoring:
      return elapsed(5000);
    case GamePhase.capturing:
      return elapsed(s.capturingStage == 0 ? 600 : 1200);
    case GamePhase.playing:
      if (s.areAllHandsEmpty) return true;
      if (s.turnStartTime == null) return false;
      final bot = s.playerIds[s.currentTurnIndex].startsWith('bot_');
      if (!bot && s.timerDurationSeconds <= 0) return false;
      return now.difference(s.turnStartTime!).inMilliseconds >=
          (bot ? 1000 : s.timerDurationSeconds * 1000);
    case GamePhase.shuffleVoting:
    case GamePhase.rematchVoting:
      final votes = s.phase == GamePhase.rematchVoting ? s.rematchVotes : s.shuffleVotes;
      return votes.values.contains(false) || elapsed(20000) ||
          s.playerIds.every((id) => votes.containsKey(id) || id.startsWith('bot_')) ||
          s.playerIds.any((id) => id.startsWith('bot_') && !votes.containsKey(id));
    case GamePhase.matchOver:
      return false;
  }
}

/// Never let delayed intent responses roll back a newer room revision.
bool canAdoptServerSnapshot(MatchState? current, MatchState incoming) =>
    current != null && current.usesServerCommands && incoming.usesServerCommands &&
    current.id == incoming.id && incoming.serverVersion >= current.serverVersion;
