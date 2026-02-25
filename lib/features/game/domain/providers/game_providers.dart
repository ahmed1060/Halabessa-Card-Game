import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';
import '../../domain/models/match_state.dart';
import '../../domain/models/capture.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine_utils.dart';
import '../../data/repositories/multiplayer_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../firebase_options.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';

final multiplayerSyncServiceProvider = Provider<MultiplayerSyncService>((ref) {
  // Use a singleton pattern or standard instance to avoid repeat initialization errors
  final db = FirebaseDatabase.instance;
  // If a custom URL is strictly needed, it should be set once in main.dart or here with a check.
  // For Halabessa, we use the default RTDB from the google-services/FirebaseOptions.
  return MultiplayerSyncService(db);
});

class MatchStateNotifier extends StateNotifier<MatchState?> {
  final Ref ref;

  MatchStateNotifier(this.ref) : super(null);
  
  // Local secret deck ONLY known by the Host (Anti-Cheat)
  Deck? _secretDeck;
  
  // Track last bound match for refresh recovery
  String? lastBoundMatchId;
  
  void _publishState(MatchState newState) {
    state = newState;
    ref.read(multiplayerSyncServiceProvider).updateMatchState(newState);
  }

  void bindToMatch(String matchId) {
    lastBoundMatchId = matchId;
    ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen((serverState) {
      if (serverState != null) {
        state = serverState;
        _evaluateBotActions(serverState);
      }
    });
  }

  void rebind(String matchId) {
    if (lastBoundMatchId == matchId && state != null) return;
    bindToMatch(matchId);
  }

  Future<void> _evaluateBotActions(MatchState serverState) async {
    // Determine if the LOCAL client is the Host (index 0) of the match.
    // We only want ONE client (the Host) to execute Bot logic to prevent duplicate Firebase writes.
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || serverState.playerIds.isEmpty) return;
    
    final isHost = serverState.playerIds.indexOf(currentUser.uid) == 0;
    if (!isHost) return;

    // Determine active turning logic
    if (serverState.phase == GamePhase.preRoundCut) {
       int cutterIdx = (serverState.dealerIndex + 3) % 4;
       String cutterId = serverState.playerIds[cutterIdx];
       if (cutterId.startsWith('bot_')) {
          await Future.delayed(const Duration(milliseconds: 1500));
          // Make sure state didn't change while waiting
          if (state?.phase == GamePhase.preRoundCut) {
             performCut(Random().nextInt(serverState.deckCount > 10 ? serverState.deckCount - 10 : 1) + 5); 
          }
       }
    } else if (serverState.phase == GamePhase.dealingFasha) {
       await Future.delayed(const Duration(milliseconds: 1000));
       if (state?.phase == GamePhase.dealingFasha) {
          dealInitialCards();
       }
    } else if (serverState.phase == GamePhase.dealingCards) {
       await Future.delayed(const Duration(milliseconds: 5000)); // 5s memorize phase
       if (state?.phase == GamePhase.dealingCards) {
          _publishState(state!.copyWith(
             phase: GamePhase.playing,
             turnStartTime: DateTime.now(),
          ));
       }
    } else if (serverState.phase == GamePhase.playing) {
       String activePlayerId = serverState.playerIds[serverState.currentTurnIndex];
       if (activePlayerId.startsWith('bot_')) {
          await Future.delayed(const Duration(milliseconds: 2000));
          // Validate state is still playing and it's still their turn
          if (state?.phase == GamePhase.playing && state!.playerIds[state!.currentTurnIndex] == activePlayerId) {
             _executeBotPlayCard(activePlayerId);
          }
       }
    } else if (serverState.phase == GamePhase.shuffleVoting || serverState.phase == GamePhase.rematchVoting) {
       // Bots auto-vote immediately
       for (var playerId in serverState.playerIds) {
          if (playerId.startsWith('bot_')) {
              if (serverState.phase == GamePhase.shuffleVoting && !serverState.shuffleVotes.containsKey(playerId)) {
                 voteShuffle(playerId, false); // Bots prefer memory mode
              } else if (serverState.phase == GamePhase.rematchVoting && !serverState.rematchVotes.containsKey(playerId)) {
                 voteRematch(playerId, true); // Bots always want to play again
              }
          }
       }
    }
  }

  void _executeBotPlayCard(String botId) {
    if (state == null) return;
    final hand = state!.handCards[botId];
    if (hand == null || hand.isEmpty) return;

    // Really simple bot: just plays a random card for now.
    // Future Enhancement: Implement Basra heuristics and pattern matching.
    final cardToPlay = hand[Random().nextInt(hand.length)];
    playCard(botId, cardToPlay);
  }

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';
    final rnd = Random();
    String c = String.fromCharCodes(Iterable.generate(3, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    String d = String.fromCharCodes(Iterable.generate(5, (_) => digits.codeUnitAt(rnd.nextInt(digits.length))));
    return c + d;
  }

  void initializeMatch(String playerId, String displayName, GameMode mode, {int timerDurationSeconds = 10, bool isPublic = false}) {
    final newId = _generateRoomId();
    final initial = MatchState(
      id: newId,
      mode: mode,
      isPublic: isPublic,
      playerIds: [playerId],
      playerNames: {playerId: displayName},
      dealerIndex: 0,
      currentTurnIndex: 1, // Player after dealer starts
      phase: GamePhase.waitingForPlayers, // Start in Lobby phase
      timerDurationSeconds: timerDurationSeconds,
    );
    ref.read(multiplayerSyncServiceProvider).createMatch(initial);
    state = initial;
    bindToMatch(newId);
  }

  void joinMatch(String matchId, String playerId, String displayName) async {
    bindToMatch(matchId);
    
    // Listen for the first non-null state specifically for this join event
    StreamSubscription? sub;
    sub = ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen((serverState) {
      if (serverState != null) {
        sub?.cancel();
        
        // Atomic Add check
        if (serverState.phase == GamePhase.waitingForPlayers && serverState.playerIds.length < 4) {
          if (!serverState.playerIds.contains(playerId)) {
             final newPlayers = List<String>.from(serverState.playerIds)..add(playerId);
             final newNames = Map<String, String>.from(serverState.playerNames)..[playerId] = displayName;
             
             _publishState(serverState.copyWith(
               playerIds: newPlayers,
               playerNames: newNames,
             ));
          }
        }
      }
    });
    
    // Safety timeout to cancel listener if room doesn't exist
    Future.delayed(const Duration(seconds: 5), () => sub?.cancel());
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
       final finalNames = Map<String, String>.from(newState.playerNames);
       int botCount = 1;
       while (finalPlayers.length < 4) {
          String botId = 'bot_$botCount';
          finalPlayers.add(botId);
          finalNames[botId] = '🤖 Bot $botCount';
          botCount++;
       }
       state = newState.copyWith(
         playerIds: finalPlayers, 
         playerNames: finalNames,
         botInjectionVotes: {}
       );
       _setupNewRound(isFirstRound: true);
    } else {
       _publishState(newState);
    }
  }

  void _setupNewRound({bool isFirstRound = false, bool forceShuffle = false}) {
    if (state == null) return;
    
    // Only Host handles deck generation (Security)
    final currentUser = ref.read(currentUserProvider);
    final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
    
    if (isHost) {
      if (isFirstRound || forceShuffle || state!.roundsSinceLastShuffle >= 5) {
        _secretDeck = Deck.standard();
        _secretDeck!.shuffle();
        state = state!.copyWith(roundsSinceLastShuffle: 0);
      } else {
        _secretDeck = Deck.restoreFromHarvest(state!.harvestStacks);
        state = state!.copyWith(roundsSinceLastShuffle: state!.roundsSinceLastShuffle + 1);
      }
    }

    _publishState(state!.copyWith(
      deckCount: isHost ? (_secretDeck?.cards.length ?? 0) : 52,
      board: [],
      recentFasha: [],
      handCards: { for (var id in state!.playerIds) id: [] },
      harvestStacks: { 'teamA': [], 'teamB': [] },
      skippedMatches: {},
      playHistory: [],
      shuffleVotes: {},
      rematchVotes: {},
      phase: GamePhase.preRoundCut,
      roundCount: state!.roundCount + (isFirstRound ? 0 : 1),
    ));
  }

  void performCut(int index) {
    if (state == null || state!.phase != GamePhase.preRoundCut) return;
    
    // Only Host manages the secret deck
    if (_secretDeck != null) {
      _secretDeck!.cut(index);
    }

    _publishState(state!.copyWith(
      deckCount: _secretDeck?.cards.length ?? 0,
      phase: GamePhase.dealingFasha,
    ));
  }

  void dealInitialCards() async {
     if (state == null || state!.phase != GamePhase.dealingFasha) return;

     final currentUser = ref.read(currentUserProvider);
     final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
     if (!isHost || _secretDeck == null) return;

     final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
     final board = <game_card.Card>[];

     // Sequential Dealing: Stagger delivery
     // 1. Board (Fasha) - 4 cards
     for (int i = 0; i < 4; i++) {
        final c = _secretDeck!.draw()!;
        board.add(c);
        _publishState(state!.copyWith(board: List.from(board), deckCount: _secretDeck!.cards.length));
        await Future.delayed(const Duration(milliseconds: 200));
     }

     // 2. Players - 4 each
     for (var playerId in state!.playerIds) {
       final playerHand = <game_card.Card>[];
       for (int i = 0; i < 4; i++) {
          final c = _secretDeck!.draw()!;
          playerHand.add(c);
          hands[playerId] = List.from(playerHand);
          _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck!.cards.length));
          await Future.delayed(const Duration(milliseconds: 200));
       }
     }

     _publishState(state!.copyWith(
       recentFasha: List.from(board),
       phase: GamePhase.dealingCards,
     ));
  }

  void dealSubsequentCards() async {
     if (state == null) return;
     
     final currentUser = ref.read(currentUserProvider);
     final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
     if (!isHost || _secretDeck == null) return;
     
     if (_secretDeck!.isEmpty) {
        _handleRoundEnd();
        return;
     }

     final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
     
     // Sequential Dealing
     for (var playerId in state!.playerIds) {
       final playerHand = <game_card.Card>[];
       for (int i = 0; i < 4; i++) {
          final c = _secretDeck!.draw()!;
          playerHand.add(c);
          hands[playerId] = List.from(playerHand);
          _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck!.cards.length));
          await Future.delayed(const Duration(milliseconds: 200));
       }
     }

     _publishState(state!.copyWith(
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

    // 1. Move card from player hand to board
    final newHand = List<game_card.Card>.from(state!.handCards[playerId]!)..remove(card);
    final newBoard = List<game_card.Card>.from(state!.board)..add(card);
    
    // Track card ownership for positional animation
    final newOwnership = Map<String, String>.from(state!.cardOwnership);
    newOwnership['${card.suit}_${card.rank}'] = playerId;

    MatchState newState = state!.copyWith(
      handCards: Map<String, List<game_card.Card>>.from(state!.handCards)..[playerId] = newHand,
      board: newBoard,
      cardOwnership: newOwnership,
    );

    final board = List<game_card.Card>.from(newState.board);
    final hands = Map<String, List<game_card.Card>>.from(newState.handCards);
    final harvest = Map<String, List<Capture>>.from(newState.harvestStacks);
    final skipped = Map<String, List<game_card.Card>>.from(newState.skippedMatches);
    final history = List<game_card.Card>.from(newState.playHistory);
    
    // 0. Behavioral Check: Did this player "skip" a capture?
    // If board has cards that match the hands OTHER than the one being played
    // We'll check if they COULD have captured with the card they just played first.
    final potentialMatchesBefore = GameEngineUtils.calculateCapture(card, board);
    if (potentialMatchesBefore.isNotEmpty) {
      // They ARE capturing. Let's check if this is a Tafweet trap from a previous skip.
      // A trap is when they capture a card that matches their 'skipped' values.
    } else {
      // They didn't capture. Did they have another card in hand that COULD have captured?
      final currentHand = hands[playerId] ?? [];
      for (var hCard in currentHand) {
        if (hCard != card) {
           final canCapture = GameEngineUtils.calculateCapture(hCard, board);
           if (canCapture.isNotEmpty) {
              // Mark these cards as "skipped" for this player
              final playerSkips = List<game_card.Card>.from(skipped[playerId] ?? [])..addAll(canCapture);
              skipped[playerId] = playerSkips;
           }
        }
      }
    }

    // Remove card from hand
    final playerHand = hands[playerId];
    if (playerHand == null) return;
    playerHand.remove(card);

    // Calculate capture
    final capturedCards = GameEngineUtils.calculateCapture(card, board);
    final teamId = _getTeamOfPlayer(playerId);
    
    // Ensure harvest stacks are initialized for this team
    if (!harvest.containsKey(teamId)) {
      harvest[teamId] = [];
    }

    int nextTurn = (state!.currentTurnIndex + 1) % 4;

    if (capturedCards.isEmpty) {
      board.add(card);
      _publishState(state!.copyWith(
        board: board,
        handCards: hands,
        skippedMatches: skipped,
        playHistory: history,
        currentTurnIndex: nextTurn,
        turnStartTime: DateTime.now(),
      ));
    } else {
      // 1 Point per Capture Rule (Standard Spec)
      int pointsEarned = 1; 
      
      bool isTafweetMode = state!.mode == GameMode.tafweet;
      bool isFirstMoveOfRound = state!.roundCount == 1 && state!.harvestStacks.values.every((v) => v.isEmpty);
      bool basra = GameEngineUtils.isBasra(card, capturedCards, board);
      
      if (basra) {
        pointsEarned += 1; // Bonus point for Basra
      }

      if (isTafweetMode) {
        // Check if this capture resolves a "skipped" trap
        final playerSkips = skipped[playerId] ?? [];
        bool isTrapMatch = playerSkips.any((s) => s.rank == card.rank);
        
        if (isTrapMatch) {
           if (isFirstMoveOfRound) {
             pointsEarned += 20; // Fasha Tafweet
             sendEmoji(playerId, '😎');
           } else {
             // Check Double Tafweet (Sequence of same rank in history)
             int sameRankCount = history.where((c) => c.rank == card.rank).length;
             if (sameRankCount >= 2) {
                pointsEarned += 30; // Double Tafweet
                sendEmoji(playerId, '🔥');
             } else {
                pointsEarned += 10; // Standard Tafweet
                sendEmoji(playerId, '😂');
             }
           }
           // Clear used trap
           skipped[playerId]?.removeWhere((s) => s.rank == card.rank);
        }
      }

      // Extract only the ACTUAL captured cards FROM the board (not including the played card yet)
      final harvestedBoardCards = List<game_card.Card>.from(capturedCards)..remove(card);

      // Remove captured cards from board
      for (var c in harvestedBoardCards) {
        board.remove(c);
      }
      
      // Add to harvest stack
      harvest[teamId]?.add(Capture(
        leadingCard: card,
        capturedCards: harvestedBoardCards,
      ));
      
      if (teamId == 'teamA') {
        state = state!.copyWith(teamAScore: state!.teamAScore + pointsEarned);
      } else {
        state = state!.copyWith(teamBScore: state!.teamBScore + pointsEarned);
      }
      
      state = state!.copyWith(lastCaptureTeam: teamId);
    }
    
    // Update Play History (Value only for sequence tracking)
    history.add(card);
    if (history.length > 10) history.removeAt(0);

    
    // Check if hands empty
    bool allHandsEmpty = hands.values.every((hand) => hand.isEmpty);

    _publishState(state!.copyWith(
      board: board,
      handCards: hands,
      harvestStacks: harvest,
      skippedMatches: skipped,
      playHistory: history,
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
