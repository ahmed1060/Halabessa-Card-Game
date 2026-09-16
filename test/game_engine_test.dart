import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/logic/game_engine_utils.dart';
import 'package:halabessa/features/game/domain/logic/score_config.dart';
import 'package:halabessa/features/game/domain/models/card.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/logic/deck.dart';

/// GameEngine is pure (state in, state out), which makes it the cheapest
/// possible regression net for the actual ruleset -- these are the first
/// tests in the repo (see HAL-15 / the revival plan's Phase 3).
void main() {
  const players = ['p0', 'p1', 'p2', 'p3'];

  MatchState buildState({
    int currentTurnIndex = 0,
    int dealerIndex = 0,
    List<Card> board = const [],
    Map<String, List<Card>> handCards = const {},
    GameMode mode = GameMode.classic,
    Map<String, List<String>> skippedMatches = const {},
    Map<String, String> cardOwnership = const {},
    List<String> playerIds = players,
  }) {
    return MatchState(
      id: 'match1',
      mode: mode,
      playerIds: playerIds,
      dealerIndex: dealerIndex,
      currentTurnIndex: currentTurnIndex,
      phase: GamePhase.playing,
      board: board,
      handCards: handCards,
      skippedMatches: skippedMatches,
      cardOwnership: cardOwnership,
    );
  }

  group('GameEngineUtils.calculateCapture', () {
    test('sweeps the whole board when the played rank matches the top card', () {
      final board = [
        const Card(Suit.hearts, Rank.three),
        const Card(Suit.clubs, Rank.jack),
      ];
      const played = Card(Suit.spades, Rank.jack);

      final captured = GameEngineUtils.calculateCapture(played, board);

      expect(captured, containsAll([...board, played]));
      expect(captured.length, board.length + 1);
    });

    test('captures nothing when the rank does not match the top card', () {
      final board = [const Card(Suit.hearts, Rank.three)];
      const played = Card(Suit.spades, Rank.jack);

      expect(GameEngineUtils.calculateCapture(played, board), isEmpty);
    });

    test('captures nothing on an empty board', () {
      const played = Card(Suit.spades, Rank.jack);
      expect(GameEngineUtils.calculateCapture(played, const []), isEmpty);
    });

    test('a JACK does not capture unless it matches the top card (no special-case)', () {
      // Regression guard: functions/index.js's old validateMove treated any
      // JACK as an automatic capture -- the real engine, and the fixed
      // Cloud Function, never have.
      final board = [const Card(Suit.hearts, Rank.three)];
      const playedJack = Card(Suit.spades, Rank.jack);
      expect(GameEngineUtils.calculateCapture(playedJack, board), isEmpty);
    });
  });

  group('GameEngine.apply(PlayCardAction)', () {
    test('rejects a play from a player who is not on turn', () {
      final hand = [const Card(Suit.hearts, Rank.two)];
      final state = buildState(currentTurnIndex: 0, handCards: {'p1': hand});

      final result = GameEngine.apply(state, PlayCardAction('p1', hand.first));

      expect(result.newState, same(state));
      expect(result.capturedCards, isEmpty);
    });

    test('a non-capturing play moves the card from hand to board and advances the turn', () {
      final card = const Card(Suit.hearts, Rank.two);
      final state = buildState(currentTurnIndex: 0, handCards: {
        'p0': [card],
      });

      final result = GameEngine.apply(state, PlayCardAction('p0', card));
      final next = result.newState;

      expect(next.board, [card]);
      expect(next.handCards['p0'], isEmpty);
      expect(next.currentTurnIndex, 1);
      expect(next.cardOwnership[card.firebaseKey], 'p0');
      expect(result.capturedCards, isEmpty);
    });

    test('turn wraps around from the last player back to the first', () {
      final card = const Card(Suit.hearts, Rank.two);
      final state = buildState(currentTurnIndex: 3, handCards: {'p3': [card]});

      final result = GameEngine.apply(state, PlayCardAction('p3', card));

      expect(result.newState.currentTurnIndex, 0);
    });

    test('a capturing play sweeps the board, credits the right team, and scores normalCapture', () {
      final onBoard = const Card(Suit.clubs, Rank.jack);
      final played = const Card(Suit.spades, Rank.jack);
      // p1 is index 1 -> odd -> teamB, per (index % 2 == 0) ? teamA : teamB.
      final state = buildState(currentTurnIndex: 1, board: [onBoard], handCards: {
        'p1': [played],
      });

      final result = GameEngine.apply(state, PlayCardAction('p1', played));
      final next = result.newState;

      expect(next.board, isEmpty);
      expect(result.capturedCards, containsAll([onBoard, played]));
      expect(result.capturingTeam, 'teamB');
      expect(next.teamBScore, ScoreConfig.normalCapture);
      expect(next.teamAScore, 0);
      expect(next.harvestStacks['teamB'], hasLength(1));
    });

    test('out-of-range currentTurnIndex leaves state unchanged instead of throwing', () {
      final state = buildState(currentTurnIndex: 5, handCards: {
        'p0': [const Card(Suit.hearts, Rank.two)],
      });

      final result = GameEngine.apply(
        state,
        PlayCardAction('p0', const Card(Suit.hearts, Rank.two)),
      );

      expect(result.newState, same(state));
    });

    test('an empty playerIds list leaves state unchanged instead of throwing', () {
      final state = buildState(currentTurnIndex: 0, playerIds: const []);

      final result = GameEngine.apply(
        state,
        PlayCardAction('p0', const Card(Suit.hearts, Rank.two)),
      );

      expect(result.newState, same(state));
    });

    test('Tafweet: skipping a matching rank then capturing it awards the standard bonus', () {
      final topCard = const Card(Suit.diamonds, Rank.five);
      final laterMatch = const Card(Suit.clubs, Rank.five);
      final nonMatchingPlay = const Card(Suit.spades, Rank.nine);

      // p0 holds a five but chooses to play a nine while a five sits on top
      // -- that's a "skip" under Tafweet rules, recorded against 'fasha'
      // (the card's source is the board, tracked via cardOwnership being
      // absent for it).
      var state = buildState(
        mode: GameMode.tafweet,
        currentTurnIndex: 0,
        board: [topCard],
        handCards: {
          'p0': [nonMatchingPlay, laterMatch],
        },
      );
      final afterSkip = GameEngine.apply(state, PlayCardAction('p0', nonMatchingPlay)).newState;
      expect(afterSkip.skippedMatches['p0'], contains('five:fasha'));

      // Next time it's p0's turn (turn order in this contrived state just
      // loops back to them) and they finally play the five they skipped,
      // Tafweet awards normalCapture + fashaTafweet.
      final afterCapture = GameEngine.apply(
        afterSkip.copyWith(currentTurnIndex: 0, board: [topCard]),
        PlayCardAction('p0', laterMatch),
      );

      expect(afterCapture.capturedCards, isNotEmpty);
      final teamAScore = afterCapture.newState.teamAScore;
      expect(teamAScore, ScoreConfig.normalCapture + ScoreConfig.fashaTafweet);
    });
  });

  group('Deck.reconstructRemaining', () {
    test('correctly reconstructs 52 minus visible cards and pins bottom cut card', () {
      const bottom = Card(Suit.spades, Rank.ace);
      final board = [const Card(Suit.hearts, Rank.two), const Card(Suit.diamonds, Rank.seven)];
      final hands = {
        'p0': [const Card(Suit.clubs, Rank.king), const Card(Suit.spades, Rank.queen)],
      };
      final harvest = {
        'teamA': [
          Capture(
            leadingCard: const Card(Suit.diamonds, Rank.jack),
            capturedCards: [const Card(Suit.hearts, Rank.jack)],
          ),
        ],
      };

      // 2 on board + 2 in hand + 2 in harvest = 6 visible cards
      // Remaining deck should have 52 - 6 = 46 cards
      final deck = Deck.reconstructRemaining(board, hands, harvest, bottomCard: bottom);

      expect(deck.remaining, 46);
      expect(deck.cards.first, bottom); // Conceptually bottom card is index 0
      
      // None of the visible cards should be in the remaining deck
      final visibleKeys = {
        const Card(Suit.hearts, Rank.two).firebaseKey,
        const Card(Suit.diamonds, Rank.seven).firebaseKey,
        const Card(Suit.clubs, Rank.king).firebaseKey,
        const Card(Suit.spades, Rank.queen).firebaseKey,
        const Card(Suit.diamonds, Rank.jack).firebaseKey,
        const Card(Suit.hearts, Rank.jack).firebaseKey,
      };
      for (final card in deck.cards) {
        expect(visibleKeys.contains(card.firebaseKey), isFalse);
      }
    });

    test('handles empty board, hands, harvest, and null bottom card', () {
      final deck = Deck.reconstructRemaining([], {}, {});
      expect(deck.remaining, 52);
    });
  });
}
