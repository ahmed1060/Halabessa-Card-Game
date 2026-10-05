import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/bot_brain.dart';
import 'package:halabessa/features/game/domain/models/bot_difficulty.dart';
import 'package:halabessa/features/game/domain/models/card.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  const hand = [
    Card(Suit.hearts, Rank.ace),
    Card(Suit.clubs, Rank.two),
    Card(Suit.spades, Rank.two),
  ];
  final s = MatchState(
    id: 'BOT',
    mode: GameMode.classic,
    playerIds: ['human', 'bot_2', 'bot_3', 'bot_4'],
    dealerIndex: 0,
    currentTurnIndex: 1,
    phase: GamePhase.playing,
    handCards: {'bot_2': hand},
    board: [const Card(Suit.diamonds, Rank.ace)],
    botDifficulties: {'bot_2': 'hard'},
  );
  test(
    'four strategies return legal decisions independent of hidden hands',
    () {
      for (final level in BotDifficulty.values) {
        final honest = BotBrain.decidePlayAdvanced(
          s,
          'bot_2',
          difficulty: level,
          rng: Random(17),
        );
        final changed = s.copyWith(
          handCards: {
            ...s.handCards,
            'human': [const Card(Suit.spades, Rank.ace)],
          },
        );
        final other = BotBrain.decidePlayAdvanced(
          changed,
          'bot_2',
          difficulty: level,
          rng: Random(17),
        );
        expect(hand, contains(honest.card));
        expect(other.card, honest.card);
        expect(
          honest.reason,
          startsWith(
            level == BotDifficulty.expert
                ? 'Capture'
                : '${level.name[0].toUpperCase()}${level.name.substring(1)}:',
          ),
        );
      }
    },
  );
  test('medium favors duplicate management without exposed-card counting', () {
    final result = BotBrain.decidePlayAdvanced(
      s.copyWith(board: []),
      'bot_2',
      difficulty: BotDifficulty.medium,
    );
    expect(result.card.rank, Rank.two);
  });
  test('counting does not count capture-animation duplicates twice', () {
    final matrix = CardCountingMatrix.fromState(
      s.copyWith(
        harvestStacks: {
          'teamA': [Capture(leadingCard: hand.first, capturedCards: s.board)],
          'teamB': [],
        },
      ),
      'bot_2',
    );
    expect(matrix.seenCounts[Rank.ace], 2);
  });
  test('difficulty persists through serialization and round copies', () {
    final decoded = MatchState.fromJson(s.toJson()).copyWith(roundCount: 2);
    expect(decoded.botDifficulties, s.botDifficulties);
    expect(parseBotDifficulty('unknown'), BotDifficulty.medium);
  });
}
