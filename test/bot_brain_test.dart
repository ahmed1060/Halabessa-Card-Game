import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/bot_brain.dart';
import 'package:halabessa/features/game/domain/models/card.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  const botId = 'bot_1';
  const playerIds = ['p0', 'bot_1', 'p2', 'p3'];

  MatchState buildState({
    List<Card> board = const [],
    Map<String, List<Card>> handCards = const {},
    Map<String, List<Capture>> harvestStacks = const {},
    GameMode mode = GameMode.classic,
    Map<String, List<String>> skippedMatches = const {},
    int currentTurnIndex = 1,
  }) {
    return MatchState(
      id: 'test_match',
      mode: mode,
      playerIds: playerIds,
      dealerIndex: 0,
      currentTurnIndex: currentTurnIndex,
      phase: GamePhase.playing,
      board: board,
      handCards: handCards,
      harvestStacks: harvestStacks,
      skippedMatches: skippedMatches,
    );
  }

  group('CardCountingMatrix', () {
    test('accurately counts cards from harvest, board, and hand', () {
      final harvest = {
        'teamA': [
          const Capture(
            leadingCard: Card(Suit.hearts, Rank.seven),
            capturedCards: [
              Card(Suit.diamonds, Rank.seven),
              Card(Suit.clubs, Rank.seven),
            ],
          ),
        ],
      };
      final board = [
        const Card(Suit.spades, Rank.jack),
      ];
      final hands = {
        botId: [
          const Card(Suit.hearts, Rank.jack),
          const Card(Suit.spades, Rank.seven), // 4th seven!
        ],
      };

      final state = buildState(
        harvestStacks: harvest,
        board: board,
        handCards: hands,
      );

      final matrix = CardCountingMatrix.fromState(state, botId);

      // Rank.seven: 3 in harvest + 1 in hand = 4 total seen!
      expect(matrix.seenCounts[Rank.seven], 4);
      expect(matrix.unseen(Rank.seven), 0);
      expect(matrix.isDeadRank(Rank.seven), isTrue);

      // Rank.jack: 1 on board + 1 in hand = 2 seen, 2 unseen
      expect(matrix.seenCounts[Rank.jack], 2);
      expect(matrix.unseen(Rank.jack), 2);
      expect(matrix.isDeadRank(Rank.jack), isFalse);

      // Rank.ace: 0 seen, 4 unseen
      expect(matrix.seenCounts[Rank.ace], isNull);
      expect(matrix.unseen(Rank.ace), 4);
    });
  });

  group('BotBrain Decision Logic', () {
    test('always captures matching top board card in classic mode', () {
      final state = buildState(
        board: [
          const Card(Suit.hearts, Rank.nine),
        ],
        handCards: {
          botId: [
            const Card(Suit.spades, Rank.two),
            const Card(Suit.clubs, Rank.nine),
            const Card(Suit.diamonds, Rank.king),
          ],
        },
      );

      final decision = BotBrain.decidePlayAdvanced(state, botId);
      expect(decision.card.rank, Rank.nine);
      expect(decision.card.suit, Suit.clubs);
    });

    test('prefers dead rank (ورقة ميتة) over dangerous rank when forced to discard', () {
      // 3 Kings are in harvest piles. Bot holds 4th King and a 3 (where 0 threes are seen).
      final harvest = {
        'teamB': [
          const Capture(
            leadingCard: Card(Suit.hearts, Rank.king),
            capturedCards: [
              Card(Suit.diamonds, Rank.king),
              Card(Suit.clubs, Rank.king),
            ],
          ),
        ],
      };

      final state = buildState(
        board: [
          const Card(Suit.hearts, Rank.five), // Board top is 5
        ],
        harvestStacks: harvest,
        handCards: {
          botId: [
            const Card(Suit.spades, Rank.three), // Dangerous: 3 unseen
            const Card(Suit.spades, Rank.king),  // Dead rank: 0 unseen!
          ],
        },
      );

      final decision = BotBrain.decidePlayAdvanced(state, botId);
      // Bot must discard King because King is dead (unseen == 0) and cannot be captured!
      expect(decision.card.rank, Rank.king);
    });

    test('avoids discarding card known to be held by next opponent', () {
      // p2 is the partner; p3 is left opponent; p0 is next opponent (since bot is at index 1: (1+1)%4 = 2 is partner?
      // Wait: playerIds = ['p0', 'bot_1', 'p2', 'p3'].
      // botIndex = 1.
      // Next opponent: (1 + 1) % 4 = 2 (in a 4-player game, teams are alternating: 0 & 2 are Team A, 1 & 3 are Team B).
      // So player 2 is an opponent!
      final state = buildState(
        board: [
          const Card(Suit.hearts, Rank.two),
        ],
        skippedMatches: {
          'p2': ['eight:fasha'], // Next opponent holds an Eight!
        },
        handCards: {
          botId: [
            const Card(Suit.spades, Rank.eight), // Dangerous: opponent holds 8!
            const Card(Suit.diamonds, Rank.six),
          ],
        },
      );

      final decision = BotBrain.decidePlayAdvanced(state, botId);
      // Bot should avoid the 8 and play the 6
      expect(decision.card.rank, Rank.six);
    });

    test('manages duplicates by discarding one to prepare future capture', () {
      final state = buildState(
        board: [
          const Card(Suit.hearts, Rank.four),
        ],
        handCards: {
          botId: [
            const Card(Suit.hearts, Rank.ten),
            const Card(Suit.spades, Rank.ten), // Two 10s!
            const Card(Suit.diamonds, Rank.two), // Single 2
          ],
        },
      );

      final decision = BotBrain.decidePlayAdvanced(state, botId);
      // With duplicates, holding two 10s makes playing a 10 safer than a single 2
      expect(decision.card.rank, Rank.ten);
    });
  });
}
