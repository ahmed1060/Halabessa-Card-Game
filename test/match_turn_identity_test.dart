import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/match_lifecycle.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  final turn = MatchState(
    id: 'ROOM',
    mode: GameMode.classic,
    playerIds: const ['a', 'b', 'c', 'd'],
    dealerIndex: 0,
    currentTurnIndex: 0,
    phase: GamePhase.playing,
    turnStartTime: DateTime.utc(2026, 10, 4),
  );

  test(
    'delayed timeout cannot target a later turn belonging to the same player',
    () {
      expect(sameMatchTurn(turn, turn.copyWith()), isTrue);
      expect(
        sameMatchTurn(
          turn,
          turn.copyWith(
            turnStartTime: turn.turnStartTime!.add(const Duration(seconds: 30)),
          ),
        ),
        isFalse,
      );
      expect(
        sameMatchTurn(turn, turn.copyWith(roundCount: turn.roundCount + 1)),
        isFalse,
      );
      expect(
        sameMatchTurn(turn, turn.copyWith(phase: GamePhase.capturing)),
        isFalse,
      );
    },
  );

  test(
    'reward completion preserves the current rematch phase and newer metadata',
    () {
      final scoring = turn.copyWith(phase: GamePhase.roundScoring);
      final latest = scoring.copyWith(
        phase: GamePhase.rematchVoting,
        rematchVotes: {'b': true},
        playerEmojis: {'c': 'hello'},
      );
      final patched = applyMatchRewards(
        latest,
        scoring,
        {'a': 50},
        {'a': 100},
      )!;
      expect(patched.phase, GamePhase.rematchVoting);
      expect(patched.rematchVotes, {'b': true});
      expect(patched.playerEmojis, {'c': 'hello'});
      expect(patched.earnedCoins, {'a': 100});
    },
  );

  test('old rewards cannot update a new room, round or restarted match', () {
    final scoring = turn.copyWith(phase: GamePhase.roundScoring);
    expect(applyMatchRewards(null, scoring, {}, {}), isNull);
    expect(
      applyMatchRewards(scoring.copyWith(id: 'OTHER'), scoring, {}, {}),
      isNull,
    );
    expect(
      applyMatchRewards(scoring.copyWith(roundCount: 99), scoring, {}, {}),
      isNull,
    );
    expect(applyMatchRewards(turn, scoring, {}, {}), isNull);
  });
}
