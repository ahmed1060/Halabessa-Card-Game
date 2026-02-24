import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import '../../domain/models/match_state.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine_utils.dart';
import '../../data/repositories/multiplayer_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../firebase_options.dart';

final multiplayerSyncServiceProvider = Provider<MultiplayerSyncService>((ref) {
  // Explicitly initialize with the databaseURL to fix Flutter Web resolution bug
  final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: DefaultFirebaseOptions.web.databaseURL!);
  return MultiplayerSyncService(db);
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

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    final rnd = Random();
    String c = String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    String d = String.fromCharCodes(Iterable.generate(5, (_) => digits.codeUnitAt(rnd.nextInt(digits.length))));
    return c + d;
  }

  void initializeMatch(List<String> playerIds, GameMode mode, {int timerDurationSeconds = 10}) {
    final newId = _generateRoomId();
    final initial = MatchState(
      id: newId,
      mode: mode,
      playerIds: playerIds,
      dealerIndex: 0,
      currentTurnIndex: 1, // Player after dealer starts
      phase: GamePhase.waitingForPlayers, // Start in Lobby phase
      timerDurationSeconds: timerDurationSeconds,
    );
    ref.read(multiplayerSyncServiceProvider).createMatch(initial);
    state = initial;
    bindToMatch(newId);
  }

  void joinMatch(String matchId, String playerId) async {
    bindToMatch(matchId);
    // Add an artificial delay to allow bindToMatch to seed the local state
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (state != null && state!.phase == GamePhase.waitingForPlayers && state!.playerIds.length < 4) {
      if (!state!.playerIds.contains(playerId)) {
         final newPlayers = List<String>.from(state!.playerIds)..add(playerId);
         _publishState(state!.copyWith(playerIds: newPlayers));
      }
    }
  }

  void voteForBots(String playerId) {
    if (state == null || state!.phase != GamePhase.waitingForPlayers) return;
    
    final votes = Map<String, bool>.from(state!.botInjectionVotes);
    votes[playerId] = true; // Mark as "Ready"
    
    MatchState newState = state!.copyWith(botInjectionVotes: votes);
    
    // Check if ALL currently connected humans are Ready
    if (votes.length == newState.playerIds.length) {
       // Unanimous Human Consent reached! Generate bots for empty seats.
       final finalPlayers = List<String>.from(newState.playerIds);
       int botCount = 1;
       while (finalPlayers.length < 4) {
          finalPlayers.add('bot_$botCount');
          botCount++;
       }
       state = newState.copyWith(playerIds: finalPlayers, botInjectionVotes: {});
       _setupNewRound(isFirstRound: true);
    } else {
       _publishState(newState);
    }
  }

  void _setupNewRound({bool isFirstRound = false, bool forceShuffle = false}) {
    if (state == null) return;
    
    Deck deck;
    
    // In Memory Mode, we should NOT shuffle unless dictated, but for Classic/Initial we do:
    if (isFirstRound) {
      deck = Deck.standard();
      deck.shuffle();
      state = state!.copyWith(roundsSinceLastShuffle: 0);
    } else if (forceShuffle || state!.roundsSinceLastShuffle >= 5) {
      deck = Deck.standard();
      deck.shuffle();
      state = state!.copyWith(roundsSinceLastShuffle: 0);
    } else {
       // Restore strictly from harvest array (Memory Mode)
       deck = Deck.restoreFromHarvest(state!.harvestStacks);
       state = state!.copyWith(roundsSinceLastShuffle: state!.roundsSinceLastShuffle + 1);
    }

    _publishState(state!.copyWith(
      deck: deck.cards,
      board: [],
      recentFasha: [],
      handCards: { for (var id in state!.playerIds) id: [] },
      harvestStacks: { 'teamA': [], 'teamB': [] },
      shuffleVotes: {},
      rematchVotes: {},
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

    int newConsecutive = state!.consecutiveTafweetCount;

    if (capturedCards.isEmpty) {
      board.add(card);
      newConsecutive = 0;
      state = state!.copyWith(consecutiveTafweetCount: newConsecutive);
    } else {
      bool isTafweetMode = state!.mode == GameMode.tafweet;
      bool isFirstMoveOfRound = state!.harvestStacks['teamA']!.isEmpty && state!.harvestStacks['teamB']!.isEmpty && board.length == 4;
      bool isBasra = GameEngineUtils.isBasra(card, capturedCards, board);
      
      if (isTafweetMode && isBasra) {
         newConsecutive += 1;
      } else {
         newConsecutive = 0;
      }
      bool isConsecutiveTafweet = newConsecutive > 1;

      int pointsEarned = GameEngineUtils.calculatePoints(
         playedCard: card,
         capturedCards: capturedCards,
         boardBeforeCapture: board,
         isTafweetMode: isTafweetMode,
         isFirstMoveOfRound: isFirstMoveOfRound,
         isConsecutiveTafweet: isConsecutiveTafweet,
      );

      // Remove captured cards from board
      for (var c in capturedCards) {
        board.remove(c);
      }
      
      // Add to harvest stack
      harvest[teamId]?.addAll(capturedCards);
      
      if (teamId == 'teamA') {
        state = state!.copyWith(teamAScore: state!.teamAScore + pointsEarned, consecutiveTafweetCount: newConsecutive);
      } else {
        state = state!.copyWith(teamBScore: state!.teamBScore + pointsEarned, consecutiveTafweetCount: newConsecutive);
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
       _publishState(endPhase.copyWith(phase: GamePhase.rematchVoting));
    } else {
       // Rotate dealer, trigger UI prompt for Shuffle/No-Shuffle
       _publishState(endPhase.copyWith(
          dealerIndex: (endPhase.dealerIndex + 1) % 4,
          phase: GamePhase.shuffleVoting,
       ));
    }
  }

  void voteShuffle(String playerId, bool wantsShuffle) {
     if (state == null || state!.phase != GamePhase.shuffleVoting) return;
     
     final votes = Map<String, bool>.from(state!.shuffleVotes);
     votes[playerId] = wantsShuffle;
     
     MatchState newState = state!.copyWith(shuffleVotes: votes);
     
     // Check if all 4 players voted
     if (votes.length == 4) {
        // If anyone voted yes, force shuffle (Memory Mode broken)
        bool forceShuffle = votes.values.any((v) => v == true);
        state = newState; 
        _setupNewRound(forceShuffle: forceShuffle);
     } else {
        _publishState(newState);
     }
  }

  void voteRematch(String playerId, bool wantsRematch) {
     if (state == null || state!.phase != GamePhase.rematchVoting) return;
     
     final votes = Map<String, bool>.from(state!.rematchVotes);
     votes[playerId] = wantsRematch;
     
     MatchState newState = state!.copyWith(rematchVotes: votes);
     
     if (votes.length == 4) {
        bool unanimous = votes.values.every((v) => v == true);
        if (unanimous) {
           // Reset Match Completely
           _publishState(newState.copyWith(
              teamAScore: 0,
              teamBScore: 0,
              roundCount: 1,
              roundsSinceLastShuffle: 0,
              consecutiveTafweetCount: 0,
              rematchVotes: {},
              shuffleVotes: {},
           ));
           _setupNewRound(isFirstRound: true);
        } else {
           // End Match completely
           _publishState(newState.copyWith(phase: GamePhase.matchOver));
        }
     } else {
        _publishState(newState);
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
