import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';

const cards = [
  game.Card(game.Suit.clubs, game.Rank.two),
  game.Card(game.Suit.clubs, game.Rank.three),
  game.Card(game.Suit.clubs, game.Rank.four),
  game.Card(game.Suit.clubs, game.Rank.five),
];
MatchState fixture() => MatchState(
  id: 'LOCAL_FEATURES',
  mode: GameMode.classic,
  playerIds: ['a', 'b', 'c', 'd'],
  dealerIndex: 0,
  currentTurnIndex: 0,
  phase: GamePhase.playing,
  handCards: {
    'a': cards,
    'b': [const game.Card(game.Suit.hearts, game.Rank.two)],
  },
);
void main() {
  test(
    'three visible reveals remain playable, per-player and separate from board',
    () {
      var state = fixture();
      for (final card in cards.take(3)) {
        state = CardFeatureState(state).showLocal('a', card);
      }
      final features = CardFeatureState(state);
      expect(features.remaining('a'), 0);
      expect(features.remaining('a', slam: true), 3);
      expect(features.remaining('b'), 3);
      expect(features.visible, hasLength(3));
      expect(state.board, isEmpty);
      expect(state.handCards['a'], cards);
      expect(() => features.showLocal('a', cards.last), throwsStateError);
      expect(features.showLocal('a', cards.first), same(state));
      expect(
        CardFeatureState(MatchState.fromJson(state.toJson())).visible,
        hasLength(3),
      );
    },
  );
  test(
    'playing a shown card hides only its copy; usage survives all hands and reconnect',
    () {
      var state = fixture();
      for (final card in cards.take(3)) {
        state = CardFeatureState(state).showLocal('a', card);
      }
      state = state.copyWith(handCards: {'a': cards.skip(1).toList()});
      expect(
        CardFeatureState(state).visible.map((item) => item.card),
        cards.skip(1).take(2),
      );
      for (var hand = 2; hand <= 3; hand++) {
        final next = CardFeatureState(state.copyWith(handInRound: hand));
        expect(next.remaining('a'), 0);
        expect(next.visible, isEmpty);
      }
      expect(CardFeatureState(state.copyWith(roundCount: 2)).remaining('a'), 3);
      expect(
        CardFeatureState(state.copyWith(matchSequence: 2)).remaining('a'),
        3,
      );
    },
  );
  test(
    'slam metadata changes no accepted gameplay fields and never spends reveal uses',
    () {
      final state = fixture(),
          accepted = fixture().copyWith(
            currentTurnIndex: 1,
            board: [cards.first],
          );
      final slammed = CardFeatureState(
        state,
      ).acceptedLocalSlam(accepted, 'a', cards.first);
      expect(slammed.board, accepted.board);
      expect(slammed.currentTurnIndex, 1);
      expect(CardFeatureState(slammed).remaining('a', slam: true), 2);
      expect(CardFeatureState(slammed).remaining('a'), 3);
    },
  );
}
