import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine_utils.dart';
import '../../data/repositories/multiplayer_sync_service.dart';

final multiplayerSyncServiceProvider = Provider<MultiplayerSyncService>((ref) {
  return MultiplayerSyncService(FirebaseDatabase.instance);
});

class MatchStateNotifier extends StateNotifier<MatchState?> {
  final Ref ref;

  MatchStateNotifier(this.ref) : super(null);
  
  void _publishState(MatchState newState) {
    state = newState;
    ref.read(multiplayerSyncServiceProvider).updateMatchState(newState);
  }

  void bindToMatch(String matchId) {
    ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen((serverState) {
      if (serverState != null) {
        state = serverState;
      }
    });
  }

  void initializeMatch(List<String> playerIds, GameMode mode, {int timerDurationSeconds = 10}) {
    const newId = 'match_\${DateTime.now().millisecondsSinceEpoch}';
    final initial = MatchState(
      id: newId,
      mode: mode,
      playerIds: playerIds,
      dealerIndex: 0,
      currentTurnIndex: 1, // Player after dealer starts
      phase: GamePhase.preRoundCut,
      timerDurationSeconds: timerDurationSeconds,
    );
    ref.read(multiplayerSyncServiceProvider).createMatch(initial);
    state = initial;
    bindToMatch(newId);
    _setupNewRound(isFirstRound: true);
  }

  void _setupNewRound({bool isFirstRound = false}) {
    if (state == null) return;
    final deck = Deck.standard();
    
    // In Memory Mode, we should NOT shuffle unless dictated, but for Classic/Initial we do:
    if (isFirstRound || state!.roundsSinceLastShuffle >= 5) {
      deck.shuffle();
      state = state!.copyWith(roundsSinceLastShuffle: 0);
    } else {
       // logic for restoring stack order goes here
       deck.shuffle(); // Placeholder for actual strict sequence restoration
       state = state!.copyWith(roundsSinceLastShuffle: state!.roundsSinceLastShuffle + 1);
    }

    _publishState(state!.copyWith(
      deck: deck.cards,
      board: [],
      recentFasha: [],
      handCards: { for (var id in state!.playerIds) id: [] },
      phase: GamePhase.preRoundCut,
      roundCount: state!.roundCount + (isFirstRound ? 0 : 1),
    ));
  }

  void performCut(int index) {
    if (state == null || state!.phase != GamePhase.preRoundCut) return;
    
    final deck = Deck(state!.deck);
    deck.cut(index);

    _publishState(state!.copyWith(
      deck: deck.cards,
      phase: GamePhase.dealingFasha,
    ));
     // Simulate showing the last card, UI will handle 5s delay using the \`deck.last\`
  }

  void dealInitialCards() {
     if (state == null || state!.phase != GamePhase.dealingFasha) return;

     final deck = Deck(state!.deck);
     final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
     final board = <game_card.Card>[];

     // Deal 4 to each player
     for (var playerId in state!.playerIds) {
       hands[playerId] = deck.drawMultiple(4);
     }

     // Deal 4 to board (Fasha)
     board.addAll(deck.drawMultiple(4));

     _publishState(state!.copyWith(
       deck: deck.cards,
       handCards: hands,
       board: board,
       recentFasha: List.from(board),
       phase: GamePhase.dealingCards, // Ready to play after preview
     ));
  }

  void dealSubsequentCards() {
     if (state == null) return;
     final deck = Deck(state!.deck);
     
     if (deck.isEmpty) {
        // Round is over
        _handleRoundEnd();
        return;
     }

     final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
     for (var playerId in state!.playerIds) {
       hands[playerId] = deck.drawMultiple(4);
     }

     _publishState(state!.copyWith(
       deck: deck.cards,
       handCards: hands,
       phase: GamePhase.playing,
       turnStartTime: DateTime.now(),
     ));
  }

  void sendEmoji(String playerId, String emoji) {
    if (state == null) return;
    final emojis = Map<String, String>.from(state!.playerEmojis);
    emojis[playerId] = emoji;
    _publishState(state!.copyWith(playerEmojis: emojis));
  }

  void clearEmoji(String playerId) {
    if (state == null) return;
    final emojis = Map<String, String>.from(state!.playerEmojis);
    emojis.remove(playerId);
    _publishState(state!.copyWith(playerEmojis: emojis));
  }

  void playCard(String playerId, game_card.Card card) {
    if (state == null || state!.phase != GamePhase.playing) return;
    
    // Validate turn
    if (state!.playerIds[state!.currentTurnIndex] != playerId) return;

    final board = List<game_card.Card>.from(state!.board);
    final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
    final harvest = Map<String, List<game_card.Card>>.from(state!.harvestStacks);
    
    // Remove card from hand
    hands[playerId]?.remove(card);

    // Calculate capture
    final capturedCards = GameEngineUtils.calculateCapture(card, board);
    final teamId = _getTeamOfPlayer(playerId);

    if (capturedCards.isEmpty) {
      board.add(card);
    } else {
      // Remove captured cards from board
      for (var c in capturedCards) {
        board.remove(c);
      }
      
      // Add to harvest stack
      harvest[teamId]?.addAll(capturedCards);
      
      // Calculate Points & Update 
      bool isTafweetMode = state!.mode == GameMode.tafweet;
      bool isFirstMoveOfRound = harvest['teamA']!.isEmpty && harvest['teamB']!.isEmpty && board.length == 4;
      
      int pointsEarned = GameEngineUtils.calculatePoints(
         playedCard: card,
         capturedCards: capturedCards,
         boardBeforeCapture: board,
         isTafweetMode: isTafweetMode,
         isFirstMoveOfRound: isFirstMoveOfRound,
         isConsecutiveTafweet: false, // Tracked separately if needed
      );
      
      if (teamId == 'teamA') {
        state = state!.copyWith(teamAScore: state!.teamAScore + pointsEarned);
      } else {
        state = state!.copyWith(teamBScore: state!.teamBScore + pointsEarned);
      }
      
      state = state!.copyWith(lastCaptureTeam: teamId);
    }

    // Determine next turn
    int nextTurn = (state!.currentTurnIndex + 1) % 4;
    
    // Check if hands empty
    bool allHandsEmpty = hands.values.every((hand) => hand.isEmpty);

    _publishState(state!.copyWith(
      board: board,
      handCards: hands,
      harvestStacks: harvest,
      currentTurnIndex: nextTurn,
      turnStartTime: DateTime.now(),
    ));

    if (allHandsEmpty) {
      dealSubsequentCards();
    }
  }

  void _handleRoundEnd() {
    if (state == null) return;
     
    final harvest = Map<String, List<game_card.Card>>.from(state!.harvestStacks);
    final board = List<game_card.Card>.from(state!.board);
    
    // Last Capture Rule
    if (board.isNotEmpty && state!.lastCaptureTeam != null) {
       harvest[state!.lastCaptureTeam!]?.addAll(board);
    }

    // Al-Ard (Majority capture points logic)
    int pointsA = state!.teamAScore;
    int pointsB = state!.teamBScore;
    
    if ((harvest['teamA']?.length ?? 0) > (harvest['teamB']?.length ?? 0)) {
       pointsA += 3;
    } else if ((harvest['teamB']?.length ?? 0) > (harvest['teamA']?.length ?? 0)) {
       pointsB += 3;
    }

    MatchState endPhase = state!.copyWith(
       board: [],
       teamAScore: pointsA,
       teamBScore: pointsB,
       phase: GamePhase.roundScoring,
    );
    
    // Check Match Win Condition
    if (pointsA >= endPhase.maxPoints || pointsB >= endPhase.maxPoints) {
       _publishState(endPhase.copyWith(phase: GamePhase.matchOver));
    } else {
       // Rotate dealer, setup next round usually happens after UI prompt for Shuffle/No-Shuffle
       _publishState(endPhase.copyWith(dealerIndex: (endPhase.dealerIndex + 1) % 4));
    }
  }

  String _getTeamOfPlayer(String playerId) {
    int index = state!.playerIds.indexOf(playerId);
    return (index == 0 || index == 2) ? 'teamA' : 'teamB';
  }
}

final matchStateProvider = StateNotifierProvider<MatchStateNotifier, MatchState?>((ref) {
  return MatchStateNotifier(ref);
});
