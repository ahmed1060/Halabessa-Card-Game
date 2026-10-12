import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/server_match_progress.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;

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
      start.add(Duration(milliseconds: 799))), false);
    expect(serverProgressDue(s.copyWith(currentTurnIndex: 1),
      start.add(Duration(milliseconds: 800))), true);
    expect(serverProgressDue(s.copyWith(playerOnlineStatus: {'human': false}),
      start.add(Duration(seconds: 1))), false);
  });
  test('capture requests one completion, never a decorative stage mutation', () {
    final capture = s.copyWith(phase: GamePhase.capturing);
    expect(serverProgressDue(capture, start.add(Duration(milliseconds: 599))), false);
    expect(serverProgressDue(capture, start.add(Duration(milliseconds: 600))), true);
    expect(serverProgressDue(capture.copyWith(capturingStage: 1),
      start.add(Duration(milliseconds: 599))), false);
    expect(serverProgressDue(capture.copyWith(capturingStage: 1),
      start.add(Duration(milliseconds: 600))), true);
  });
  test('one public hand count auto-plays only the active turn, even without a timer', () {
    final single = s.copyWith(timerDurationSeconds: 0,
      handCounts: {'human': 1, 'bot_1': 4, 'bot_2': 4, 'bot_3': 4});
    expect(serverProgressDue(single, start.add(const Duration(milliseconds: 899))), false);
    expect(serverProgressDue(single, start.add(const Duration(milliseconds: 900))), true);
    expect(serverProgressDue(single.copyWith(currentTurnIndex: 1),
      start.add(const Duration(milliseconds: 799))), false);
    expect(serverProgressDue(single.copyWith(currentTurnIndex: 1),
      start.add(const Duration(milliseconds: 800))), true);
    expect(serverProgressDue(single.copyWith(phase: GamePhase.dealingCards),
      start.add(const Duration(milliseconds: 600))), false);
  });
  test('private own single-card hand can hint forced play without public counts', () {
    final single = s.copyWith(handCounts: {}, handCards: {
      'human': [const game.Card(game.Suit.hearts, game.Rank.ace)]});
    expect(serverProgressDue(single, start.add(const Duration(milliseconds: 899))), false);
    expect(serverProgressDue(single, start.add(const Duration(milliseconds: 900))), true);
    expect(serverProgressDue(single.copyWith(turnStartTime: start.add(const Duration(seconds: 1))),
      start.add(const Duration(milliseconds: 600))), false);
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
    expect(canAdoptServerSnapshot(s, s), false);
    final own = s.copyWith(handCards: {'human': []});
    expect(canAdoptServerSnapshot(s, own), true);
    expect(canAdoptServerSnapshot(own, own), false);
  });
  test('phase timestamp survives model round trips and copies', () {
    final decoded = MatchState.fromJson(s.toJson());
    expect(decoded.copyWith(serverVersion: 4).phaseStartedAt, start);
  });
}
