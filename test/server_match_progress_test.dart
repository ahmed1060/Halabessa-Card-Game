import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/server_match_progress.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  final start = DateTime.utc(2026, 10, 4);
  final s = MatchState(id: 'ROOM1234', mode: GameMode.classic,
    protocolVersion: 1, serverVersion: 3,
    playerIds: ['human', 'bot_1', 'bot_2', 'bot_3'],
    dealerIndex: 0, currentTurnIndex: 0, phase: GamePhase.playing,
    turnStartTime: start, phaseStartedAt: start,
    handCounts: {'human': 4, 'bot_1': 4, 'bot_2': 4, 'bot_3': 4});

  test('human deadline and timer-free play do not trigger early', () {
    expect(serverProgressDue(s, start.add(Duration(seconds: 9))), false);
    expect(serverProgressDue(s, start.add(Duration(seconds: 10))), true);
    expect(serverProgressDue(s.copyWith(timerDurationSeconds: 0),
      start.add(Duration(days: 1))), false);
  });
  test('only true bot seat can request an early automatic move', () {
    expect(serverProgressDue(s.copyWith(currentTurnIndex: 1),
      start.add(Duration(milliseconds: 999))), false);
    expect(serverProgressDue(s.copyWith(currentTurnIndex: 1),
      start.add(Duration(seconds: 1))), true);
    expect(serverProgressDue(s.copyWith(playerOnlineStatus: {'human': false}),
      start.add(Duration(seconds: 1))), false);
  });
  test('capture phases honor the distinct stage deadlines', () {
    final capture = s.copyWith(phase: GamePhase.capturing);
    expect(serverProgressDue(capture, start.add(Duration(milliseconds: 599))), false);
    expect(serverProgressDue(capture, start.add(Duration(milliseconds: 600))), true);
    expect(serverProgressDue(capture.copyWith(capturingStage: 1),
      start.add(Duration(milliseconds: 1199))), false);
    expect(serverProgressDue(capture.copyWith(capturingStage: 1),
      start.add(Duration(milliseconds: 1200))), true);
  });
  test('memory and scoring phases use phase clock instead of turn clock', () {
    for (final phase in [GamePhase.dealingCards, GamePhase.roundScoring]) {
      final current = s.copyWith(phase: phase, turnStartTime: start.subtract(Duration(days: 1)));
      expect(serverProgressDue(current, start.add(Duration(milliseconds: 4999))), false);
      expect(serverProgressDue(current, start.add(Duration(seconds: 5))), true);
    }
  });
  test('empty public hand counts request deal/end without opponent cards', () {
    expect(serverProgressDue(s.copyWith(handCounts: {
      for (final id in s.playerIds) id: 0}), start), true);
  });
  test('preparation bounded even when human gameplay timer disabled', () {
    final prep = s.copyWith(phase: GamePhase.preRoundCut,
      playerIds: ['bot_1', 'bot_2', 'bot_3', 'human'], timerDurationSeconds: 0);
    expect(serverProgressDue(prep, start.add(Duration(seconds: 14))), false);
    expect(serverProgressDue(prep, start.add(Duration(seconds: 15))), true);
  });
  test('legacy matches and incomplete lobbies stay out of server scheduler', () {
    expect(serverProgressDue(s.copyWith(protocolVersion: 0), start.add(Duration(days: 1))), false);
    expect(serverProgressDue(s.copyWith(phase: GamePhase.waitingForPlayers,
      playerIds: ['human', 'waiting_1', 'waiting_2', 'waiting_3']), start), false);
  });
  test('adoption rejects delayed older and unrelated room responses', () {
    expect(canAdoptServerSnapshot(s, s.copyWith(serverVersion: 2)), false);
    expect(canAdoptServerSnapshot(s, s.copyWith(id: 'OTHER123', serverVersion: 4)), false);
    expect(canAdoptServerSnapshot(null, s), false);
    expect(canAdoptServerSnapshot(s, s.copyWith(serverVersion: 4)), true);
  });
  test('phase timestamp survives model round trips and copies', () {
    final decoded = MatchState.fromJson(s.toJson());
    expect(decoded.copyWith(serverVersion: 4).phaseStartedAt, start);
  });
}
