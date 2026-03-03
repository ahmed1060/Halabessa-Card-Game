import '../models/match_state.dart';
import '../models/game_action.dart';
import '../models/card.dart' as game_card;
import '../models/capture.dart';
import 'game_engine_utils.dart';
import 'deck.dart';

class GameEngine {
  
  /// Applies a GameAction to the current MatchState and returns the new state.
  /// Also returns a list of resulting "Side Effects" (like captured cards) for UI animations.
  static GameEngineResult apply(MatchState state, GameAction action, {Deck? secretDeck}) {
    if (action is PlayCardAction) {
      return _playCard(state, action);
    } else if (action is CutAction) {
      return _cut(state, action, secretDeck);
    } else if (action is DealAction) {
      return _deal(state, action, secretDeck);
    } else if (action is VoteAction) {
      return _vote(state, action);
    }
    return GameEngineResult(state);
  }

  static GameEngineResult _playCard(MatchState state, PlayCardAction action) {
    if (state.phase != GamePhase.playing) return GameEngineResult(state);
    
    final playerId = action.playerId;
    final card = action.card;
    
    // Validate turn
    if (state.playerIds[state.currentTurnIndex] != playerId) return GameEngineResult(state);

    // 1. Prepare local state
    final board = List<game_card.Card>.from(state.board);
    final hands = Map<String, List<game_card.Card>>.from(state.handCards);
    final harvest = Map<String, List<Capture>>.from(state.harvestStacks);
    final skipped = Map<String, List<String>>.from(state.skippedMatches);
    final ownership = Map<String, String>.from(state.cardOwnership);
    final emojis = Map<String, String>.from(state.playerEmojis);
    
    // Check for skips (Tafweet rules)
    if (board.isNotEmpty) {
      final topCard = board.last;
      bool hasMatchInHand = hands[playerId]?.any((c) => c.rank == topCard.rank) ?? false;
      
      if (hasMatchInHand && card.rank != topCard.rank) {
        final sourceId = ownership[topCard.firebaseKey] ?? 'fasha';
        final skipKey = '${topCard.rank.name}:$sourceId';
        
        final playerSkips = List<String>.from(skipped[playerId] ?? []);
        if (!playerSkips.contains(skipKey)) {
          playerSkips.add(skipKey);
          skipped[playerId] = playerSkips;
        }
      }
    }

    // 2. Remove card from hand
    hands[playerId]?.removeWhere((c) => c.firebaseKey == card.firebaseKey);

    // 3. Calculate capture
    final capturedCards = GameEngineUtils.calculateCapture(card, board);
    final teamId = (state.playerIds.indexOf(playerId) % 2 == 0) ? 'teamA' : 'teamB';
    int pointsEarned = 0;
    int nextTurn = (state.currentTurnIndex + 1) % 4;

    if (capturedCards.isEmpty) {
      board.add(card);
      ownership[card.firebaseKey] = playerId;

      return GameEngineResult(
        state.copyWith(
          board: board,
          handCards: hands,
          skippedMatches: skipped,
          cardOwnership: ownership,
          currentTurnIndex: nextTurn,
          turnStartTime: DateTime.now(),
        ),
      );
    } else {
      pointsEarned = 1;
      
      // Handle Tafweet bonus points
      if (state.mode == GameMode.tafweet) {
        final playerSkips = List<String>.from(skipped[playerId] ?? []);
        final previousPlayerId = state.playerIds[(state.currentTurnIndex + 3) % 4];
        
        bool isFashaTafweet = playerSkips.contains('${card.rank.name}:fasha');
        int rankSkipCount = playerSkips.where((s) => s.startsWith('${card.rank.name}:')).length;
        bool isDoubleTafweet = rankSkipCount >= 2 && playerSkips.contains('${card.rank.name}:$previousPlayerId');
        bool isStandardTafweet = playerSkips.contains('${card.rank.name}:$previousPlayerId');

        if (isFashaTafweet) {
          pointsEarned += 5;
          emojis[playerId] = '😎';
          playerSkips.remove('${card.rank.name}:fasha');
        } else if (isDoubleTafweet) {
          pointsEarned += 10;
          emojis[playerId] = '🔥';
          playerSkips.removeWhere((s) => s.startsWith('${card.rank.name}:'));
        } else if (isStandardTafweet) {
          pointsEarned += 5;
          emojis[playerId] = '😂';
          playerSkips.removeWhere((s) => s.startsWith('${card.rank.name}:'));
        }
        skipped[playerId] = playerSkips;
      }

      final harvestedCards = List<game_card.Card>.from(capturedCards)..removeWhere((c) => c.firebaseKey == card.firebaseKey);
      final keysToRemove = capturedCards.map((c) => c.firebaseKey).toSet();
      board.removeWhere((c) => keysToRemove.contains(c.firebaseKey));
      
      if (!harvest.containsKey(teamId)) harvest[teamId] = [];
      harvest[teamId]?.add(Capture(leadingCard: card, capturedCards: harvestedCards));

      return GameEngineResult(
        state.copyWith(
          board: board,
          handCards: hands,
          harvestStacks: harvest,
          skippedMatches: skipped,
          cardOwnership: ownership,
          playerEmojis: emojis,
          currentTurnIndex: nextTurn,
          teamAScore: state.teamAScore + (teamId == 'teamA' ? pointsEarned : 0),
          teamBScore: state.teamBScore + (teamId == 'teamB' ? pointsEarned : 0),
          lastCaptureTeam: teamId,
          turnStartTime: DateTime.now(),
        ),
        capturedCards: capturedCards,
        capturingTeam: teamId,
      );
    }
  }

  static GameEngineResult _cut(MatchState state, CutAction action, Deck? secretDeck) {
    if (state.phase != GamePhase.preRoundCut) return GameEngineResult(state);
    
    // Only cutter can cut
    int cutterIdx = (state.dealerIndex + 3) % 4;
    if (state.playerIds[cutterIdx] != action.playerId) return GameEngineResult(state);

    if (secretDeck != null) {
      secretDeck.cut(action.cutIndex);
    }

    final lastCard = secretDeck?.cards.first;
    
    return GameEngineResult(
      state.copyWith(
        deckCount: secretDeck?.cards.length ?? 0,
        phase: GamePhase.dealingFasha,
        cutLastCard: lastCard,
      ),
    );
  }

  static GameEngineResult _deal(MatchState state, DealAction action, Deck? secretDeck) {
    if (secretDeck == null) return GameEngineResult(state);
    
    final hands = Map<String, List<game_card.Card>>.from(state.handCards);
    final board = List<game_card.Card>.from(state.board);
    
    if (action.isInitial) {
      // Deal 4 to board
      for (int i = 0; i < 4; i++) {
        final c = secretDeck.draw();
        if (c != null) board.add(c);
      }
      // Deal 4 to each player
      for (var id in state.playerIds) {
        final playerHand = <game_card.Card>[];
        for (int i = 0; i < 4; i++) {
          final c = secretDeck.draw();
          if (c != null) playerHand.add(c);
        }
        hands[id] = playerHand;
      }
      
      return GameEngineResult(
        state.copyWith(
          board: board,
          handCards: hands,
          deckCount: secretDeck.cards.length,
          recentFasha: List.from(board),
          handInRound: 1,
          phase: GamePhase.dealingCards,
        ),
      );
    } else {
      // Subsequent deal
      for (var id in state.playerIds) {
        final playerHand = List<game_card.Card>.from(hands[id] ?? []);
        for (int i = 0; i < 4; i++) {
          final c = secretDeck.draw();
          if (c != null) playerHand.add(c);
        }
        hands[id] = playerHand;
      }
      
      return GameEngineResult(
        state.copyWith(
          handCards: hands,
          deckCount: secretDeck.cards.length,
          handInRound: state.handInRound + 1,
          phase: GamePhase.playing,
          turnStartTime: DateTime.now(),
        ),
      );
    }
  }

  static GameEngineResult _vote(MatchState state, VoteAction action) {
    if (action.isRematch) {
      final votes = Map<String, bool>.from(state.rematchVotes);
      votes[action.playerId] = action.vote;
      return GameEngineResult(state.copyWith(rematchVotes: votes));
    } else {
      final votes = Map<String, bool>.from(state.shuffleVotes);
      votes[action.playerId] = action.vote;
      return GameEngineResult(state.copyWith(shuffleVotes: votes));
    }
  }
}

class GameEngineResult {
  final MatchState newState;
  final List<game_card.Card> capturedCards;
  final String? capturingTeam;

  GameEngineResult(this.newState, {this.capturedCards = const [], this.capturingTeam});
}
