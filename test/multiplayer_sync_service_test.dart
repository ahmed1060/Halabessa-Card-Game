import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  test('command snapshot keeps public opponent counts and only caller cards', () {
    final state = MultiplayerSyncService.commandSnapshot({
      'state': {'id': 'ABC12345', 'mode': 'classic', 'serverVersion': 8,
        'playerIds': ['human', 'bot_1', 'bot_2', 'bot_3'],
        'handCounts': {'human': 1, 'bot_1': 4, 'bot_2': 3, 'bot_3': 2},
        'handCards': {'bot_1': [{'suit': 'clubs', 'rank': 'king'}]}},
      'hand': [{'suit': 'hearts', 'rank': 'ace'}],
    }, 'human');
    expect(state.serverVersion, 8);
    expect(state.handCards.keys, ['human']);
    expect(state.cardsRemainingFor('bot_1'), 4);
    expect(state.cardsRemainingFor('bot_2'), 3);
    expect(state.handCards['human'], hasLength(1));
  });
  test('empty command hand clears stale cards without clearing opponent counts', () {
    final state = MultiplayerSyncService.commandSnapshot({
      'state': {'id': 'ABC12345', 'mode': 'classic',
        'playerIds': ['human', 'bot_1', 'bot_2', 'bot_3'],
        'handCounts': {'human': 0, 'bot_1': 4, 'bot_2': 3, 'bot_3': 2}},
    }, 'human');
    expect(state.handCards['human'], isEmpty);
    expect(state.cardsRemainingFor('bot_1'), 4);
  });
  test('sparse private hand snapshot clears counts for omitted empty hands', () {
    final publicState = <String, dynamic>{
      'id': 'ABC12345',
      'mode': GameMode.classic.name,
      'playerIds': ['human', 'bot_1', 'bot_2', 'bot_3'],
      'handCounts': {'human': 4, 'bot_1': 4, 'bot_2': 4, 'bot_3': 4},
    };

    // RTDB omits the empty-hand keys and retains only players with cards.
    final merged = MultiplayerSyncService.mergePrivateHands(publicState, {
      'bot_2': [
        {'suit': 'hearts', 'rank': 'ace'},
      ],
    });
    final state = MatchState.fromJson(merged);

    expect(state.cardsRemainingFor('human'), 0);
    expect(state.cardsRemainingFor('bot_1'), 0);
    expect(state.cardsRemainingFor('bot_2'), 1);
    expect(state.cardsRemainingFor('bot_3'), 0);
    expect(state.areAllHandsEmpty, isFalse);
  });

  test('empty private hand snapshot clears every stale public hand count', () {
    final merged = MultiplayerSyncService.mergePrivateHands(
      {
        'id': 'ABC12345',
        'mode': GameMode.classic.name,
        'playerIds': ['human', 'bot_1', 'bot_2', 'bot_3'],
        'handCounts': {'human': 4, 'bot_1': 4, 'bot_2': 4, 'bot_3': 4},
      },
      null,
    );
    final state = MatchState.fromJson(merged);

    expect(state.handCounts.values, everyElement(0));
    expect(state.areAllHandsEmpty, isTrue);
  });
}

