import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/logic/deck.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

void main() {
  const players = ['one', 'two', 'three', 'four'];
  for (var dealer = 0; dealer < 4; dealer++) {
    test('dealer seat $dealer alone can cut; next player still starts', () {
      final state = MatchState(
        id: 'OFFLINE_CUT_RULE',
        mode: GameMode.classic,
        playerIds: players,
        dealerIndex: dealer,
        currentTurnIndex: (dealer + 1) % 4,
        phase: GamePhase.preRoundCut,
      );
      final deck = Deck.standard();
      final original = List.of(deck.cards);
      for (final uid in players.where((uid) => uid != players[dealer])) {
        expect(
          GameEngine.apply(
            state,
            CutAction(uid, 20),
            secretDeck: deck,
          ).newState,
          same(state),
        );
        expect(deck.cards, original);
      }
      final result = GameEngine.apply(
        state,
        CutAction(players[dealer], 20),
        secretDeck: deck,
      ).newState;
      expect(result.phase, GamePhase.dealingFasha);
      expect(result.currentTurnIndex, (dealer + 1) % 4);
      expect(result.deckCount, 52);
      expect(result.cutLastCard, deck.cards.first);
      expect(deck.cards.toSet(), original.toSet());
    });
  }
}
