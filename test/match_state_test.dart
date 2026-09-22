import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  test('preserves authoritative version and public hand counts', () {
    final state = MatchState.fromJson({
      'id': 'ABC12345',
      'mode': 'classic',
      'playerIds': ['one', 'two', 'three', 'four'],
      'dealerIndex': 0,
      'currentTurnIndex': 1,
      'serverVersion': 17,
      'handCounts': {'one': 3, 'two': 0, 'three': 2, 'four': 1},
    });

    expect(state.serverVersion, 17);
    expect(state.cardsRemainingFor('three'), 2);
    expect(state.areAllHandsEmpty, isFalse);
    expect(state.toJson()['serverVersion'], 17);
    expect(state.toJson()['handCounts'], state.handCounts);
  });

  test('derives counts for offline states that contain full hands', () {
    final state = MatchState.fromJson({
      'id': 'OFFLINE_TEST',
      'mode': GameMode.classic.name,
      'playerIds': ['one'],
      'dealerIndex': 0,
      'currentTurnIndex': 0,
      'handCards': {
        'one': [
          {'suit': 'hearts', 'rank': 'ace'},
        ],
      },
    });

    expect(state.cardsRemainingFor('one'), 1);
    expect(state.areAllHandsEmpty, isFalse);
  });
}
