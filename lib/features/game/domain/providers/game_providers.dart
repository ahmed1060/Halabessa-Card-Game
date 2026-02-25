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
  
  // Prevents multiple concurrent bot logic evaluations for the same state change
  bool _isHandlingBotLogic = false;

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

    if (_isHandlingBotLogic) return;
    _isHandlingBotLogic = true;
    
    try {
      // Determine active turning logic
      if (serverState.phase == GamePhase.preRoundCut) {
        int cutterIdx = (serverState.dealerIndex + 3) % 4;
        String cutterId = serverState.playerIds[cutterIdx];
        if (cutterId.startsWith('bot_')) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (state?.phase == GamePhase.preRoundCut) {
            performCut(Random().nextInt(serverState.deckCount > 10 ? serverState.deckCount - 10 : 1) + 5); 
          }
        }
      } else if (serverState.phase == GamePhase.dealingFasha) {
        // This is where Host deals Initial Board + Hands
        await Future.delayed(const Duration(milliseconds: 500));
        if (state?.phase == GamePhase.dealingFasha) {
          await dealInitialCards();
        }
      } else if (serverState.phase == GamePhase.dealingCards) {
        // This is the "Memorize Fasha" 5s phase
        await Future.delayed(const Duration(milliseconds: 5000));
        if (state?.phase == GamePhase.dealingCards) {
          _publishState(state!.copyWith(
            phase: GamePhase.playing,
            turnStartTime: DateTime.now(),
          ));
        }
      } else if (serverState.phase == GamePhase.playing) {
        String activePlayerId = serverState.playerIds[serverState.currentTurnIndex];
        if (activePlayerId.startsWith('bot_')) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (state?.phase == GamePhase.playing && state!.playerIds[state!.currentTurnIndex] == activePlayerId) {
            _executeBotPlayCard(activePlayerId);
          }
        }
      } else if (serverState.phase == GamePhase.shuffleVoting || serverState.phase == GamePhase.rematchVoting) {
        for (var playerId in serverState.playerIds) {
          if (playerId.startsWith('bot_')) {
            if (serverState.phase == GamePhase.shuffleVoting && !serverState.shuffleVotes.containsKey(playerId)) {
              voteShuffle(playerId, false);
            } else if (serverState.phase == GamePhase.rematchVoting && !serverState.rematchVotes.containsKey(playerId)) {
              voteRematch(playerId, true);
            }
          }
        }
      }
    } finally {
      _isHandlingBotLogic = false;
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

  Future<void> dealInitialCards() async {
     if (state == null || state!.phase != GamePhase.dealingFasha) return;

     final currentUser = ref.read(currentUserProvider);
     final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
     if (!isHost || _secretDeck == null) return;

     final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
     final board = <game_card.Card>[];

     // Sequential Dealing: Stagger delivery
     // 1. Board (Fasha) - 4 cards
     for (int i = 0; i < 4; i++) {
        final c = _secretDeck?.draw();
        if (c == null) break;
        board.add(c);
        _publishState(state!.copyWith(board: List.from(board), deckCount: _secretDeck?.cards.length ?? 0));
        await Future.delayed(const Duration(milliseconds: 250));
     }

     // 2. Players - 4 each
     for (var playerId in state!.playerIds) {
       final playerHand = <game_card.Card>[];
       for (int i = 0; i < 4; i++) {
          final c = _secretDeck?.draw();
          if (c == null) break;
          playerHand.add(c);
          hands[playerId] = List.from(playerHand);
          _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck?.cards.length ?? 0));
          await Future.delayed(const Duration(milliseconds: 250));
       }
     }

     _publishState(state!.copyWith(
       recentFasha: List.from(board),
       phase: GamePhase.dealingCards,
     ));
  }

  Future<void> dealSubsequentCards() async {
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
          final c = _secretDeck?.draw();
          if (c == null) break;
          playerHand.add(c);
          hands[playerId] = List.from(playerHand);
          _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck?.cards.length ?? 0));
          await Future.delayed(const Duration(milliseconds: 250));
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

    // 1. Prepare local state
    final prePlayBoard = List<game_card.Card>.from(state!.board);
    final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
    final harvest = Map<String, List<Capture>>.from(state!.harvestStacks);
    final skipped = Map<String, List<String>>.from(state!.skippedMatches);
    final history = List<game_card.Card>.from(state!.playHistory);
    final ownership = Map<String, String>.from(state!.cardOwnership);
    
    // 0. Detect Skips (Deliberately not capturing)
    if (prePlayBoard.isNotEmpty) {
      final topCard = prePlayBoard.last;
      bool hasMatchInHand = hands[playerId]?.any((c) => c.rank == topCard.rank) ?? false;
      
      // If they have a match but chosen card rank DOES NOT match the top card
      if (hasMatchInHand && card.rank != topCard.rank) {
        final sourceId = ownership['${topCard.suit}_${topCard.rank}'] ?? 'fasha';
        final skipKey = '${topCard.rank.name}:$sourceId';
        
        final playerSkips = List<String>.from(skipped[playerId] ?? []);
        if (!playerSkips.contains(skipKey)) {
          playerSkips.add(skipKey);
          skipped[playerId] = playerSkips;
        }
      }
    }

    // 1. Remove card from player hand
    hands[playerId]?.remove(card);

    // 2. Calculate capture (using refined Top-Match rules in calculateCapture)
    final capturedCards = GameEngineUtils.calculateCapture(card, prePlayBoard);
    final teamId = _getTeamOfPlayer(playerId);
    
    // Ensure harvest stacks are initialized
    if (!harvest.containsKey(teamId)) {
      harvest[teamId] = [];
    }

    int pointsEarned = 0;
    int nextTurn = (state!.currentTurnIndex + 1) % 4;
    List<game_card.Card> finalBoard = List.from(prePlayBoard);

    if (capturedCards.isEmpty) {
      // No capture: Add card to board and track ownership
      finalBoard.add(card);
      ownership['${card.suit}_${card.rank}'] = playerId;
    } else {
      // Capture: Calculate points and Tafweets
      pointsEarned = 1; 
      
      bool isTafweetMode = state!.mode == GameMode.tafweet;
      bool basra = GameEngineUtils.isBasra(card, capturedCards, prePlayBoard);
      
      if (basra) {
        pointsEarned += 1; 
      }

      if (isTafweetMode) {
        final playerSkips = List<String>.from(skipped[playerId] ?? []);
        final previousPlayerId = state!.playerIds[(state!.currentTurnIndex + 3) % 4];
        
        bool isFashaTafweet = playerSkips.contains('${card.rank.name}:fasha');
        int rankSkipCount = playerSkips.where((s) => s.startsWith('${card.rank.name}:')).length;
        bool isDoubleTafweet = rankSkipCount >= 2 && playerSkips.contains('${card.rank.name}:$previousPlayerId');
        bool isStandardTafweet = playerSkips.contains('${card.rank.name}:$previousPlayerId');

        if (isFashaTafweet) {
          pointsEarned += 20;
          sendEmoji(playerId, '😎');
          playerSkips.remove('${card.rank.name}:fasha');
        } else if (isDoubleTafweet) {
          pointsEarned += 30;
          sendEmoji(playerId, '🔥');
          playerSkips.removeWhere((s) => s.startsWith('${card.rank.name}:'));
        } else if (isStandardTafweet) {
          pointsEarned += 10;
          sendEmoji(playerId, '😂');
          playerSkips.removeWhere((s) => s.startsWith('${card.rank.name}:'));
        }
        skipped[playerId] = playerSkips;
      }

      // Process harvested cards
      final harvestedBoardCards = List<game_card.Card>.from(capturedCards)..remove(card);
      for (var c in harvestedBoardCards) {
        finalBoard.remove(c);
      }
      
      harvest[teamId]?.add(Capture(
        leadingCard: card,
        capturedCards: harvestedBoardCards,
      ));
    }
    
    // 3. Update Play History
    history.add(card);
    if (history.length > 10) history.removeAt(0);

    // 4. Update state atomically
    final allHandsEmpty = hands.values.every((hand) => hand.isEmpty);

    _publishState(state!.copyWith(
      board: finalBoard,
      handCards: hands,
      harvestStacks: harvest,
      skippedMatches: skipped,
      playHistory: history,
      cardOwnership: ownership,
      currentTurnIndex: nextTurn,
      teamAScore: state!.teamAScore + (teamId == 'teamA' ? pointsEarned : 0),
      teamBScore: state!.teamBScore + (teamId == 'teamB' ? pointsEarned : 0),
      lastCaptureTeam: pointsEarned > 0 ? teamId : state!.lastCaptureTeam,
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
       _publishState(endPhase.copyWith(
          phase: GamePhase.rematchVoting,
          skippedMatches: {},
          playHistory: [],
       ));
    } else {
       // Rotate dealer, trigger UI prompt for Shuffle/No-Shuffle
       _publishState(endPhase.copyWith(
          dealerIndex: (endPhase.dealerIndex + 1) % 4,
          phase: GamePhase.shuffleVoting,
          skippedMatches: {},
          playHistory: [],
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
