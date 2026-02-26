import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import '../../domain/models/match_state.dart';
import '../../domain/models/capture.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine_utils.dart';
import '../../data/repositories/multiplayer_sync_service.dart';
import 'package:flutter/foundation.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/services/multimedia_service.dart';

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

  MultimediaService get _multimedia => ref.read(multimediaServiceProvider);
  
  // Local secret deck ONLY known by the Host (Anti-Cheat)
  Deck? _secretDeck;
  
  // Track last bound match for refresh recovery
  String? lastBoundMatchId;
  
  // Prevents multiple concurrent bot logic evaluations for the same state change
  bool _isHandlingBotLogic = false;
  Timer? _heartbeatTimer;
  Timer? _autoplayTimer;
  
  // Stream subscription for the match listener
  StreamSubscription? _matchListener;
  StreamSubscription? _presenceListener;

  Future<void> _publishState(MatchState newState) async {
    state = newState;
    await ref.read(multiplayerSyncServiceProvider).updateMatchState(newState);
  }

  static const String _matchIdKey = 'last_match_id';

  Future<void> _saveMatchId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_matchIdKey, id);
  }

  Future<void> _clearMatchId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchIdKey);
  }

  Future<void> tryRecoverLastMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_matchIdKey);
    if (lastId != null && state == null) {
       debugPrint('RECOVERY: Attempting to recover match $lastId');
       bindToMatch(lastId);
    }
  }

  void leaveMatch() {
    _matchListener?.cancel();
    _presenceListener?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    state = null;
    _clearMatchId();
  }

  void bindToMatch(String matchId) {
    lastBoundMatchId = matchId;
    _saveMatchId(matchId);
    _matchListener?.cancel(); // Cancel previous listener if any
    _matchListener = ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen(
      (serverState) {
        if (serverState != null) {
          try {
            state = serverState;
            
            // Manage Heartbeat: Start if Host, stop if not
            final currentUser = ref.read(currentUserProvider);
            if (currentUser != null && serverState.playerIds.indexOf(currentUser.uid) == 0) {
              if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
                _heartbeatTimer?.cancel();
                _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
                   if (state != null) _evaluateBotActions(state!);
                });
              }
            } else {
              _heartbeatTimer?.cancel();
              _heartbeatTimer = null;
            }

            _evaluateBotActions(serverState);
            _manageAutoplayTimer(serverState);
          } catch (e, stack) {
            debugPrint('ERROR in match listener callback: $e');
            debugPrint('Stack: $stack');
          }
        }
      },
      onError: (error) {
        debugPrint('MATCH LISTENER STREAM ERROR: $error');
      },
      cancelOnError: false,
    );

    // Sync Presence
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(multiplayerSyncServiceProvider).syncPresence(matchId, currentUser.uid);
    }

    // Host Presence Watcher
    _presenceListener?.cancel();
    _presenceListener = ref.read(multiplayerSyncServiceProvider).watchPresence(matchId).listen((presence) {
       final serverState = state;
       if (serverState == null) return;
       
       final isHost = currentUser != null && serverState.playerIds.indexOf(currentUser.uid) == 0;
       if (!isHost) return;

       final newOnlineStatus = Map<String, bool>.from(serverState.playerOnlineStatus);
       bool changed = false;

       for (var playerId in serverState.playerIds) {
         final isOnline = presence[playerId] == true;
         // Special case: if prefix is bot_, always online
         final actualOnline = playerId.startsWith('bot_') ? true : isOnline;
         if (newOnlineStatus[playerId] != actualOnline) {
           newOnlineStatus[playerId] = actualOnline;
           changed = true;
         }
       }

       if (changed) {
         _publishState(serverState.copyWith(playerOnlineStatus: newOnlineStatus));
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
    
    // Safety delay to allow state to settle
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final currentState = serverState;
      if (currentState.playerIds.isEmpty) return;
      // Host specific global phase handling (Dealing Cards)
      if (currentState.phase == GamePhase.dealingFasha) {
        // This is where Host deals Initial Board + Hands
        await Future.delayed(const Duration(milliseconds: 500));
        if (state?.phase == GamePhase.dealingFasha) {
          await dealInitialCards();
        }
      } else if (currentState.phase == GamePhase.waitingForPlayers) {
        // LOBBY AUTO-START: If 4 players join, Host triggers start automatically.
        if (currentState.playerIds.length == 4) {
          await Future.delayed(const Duration(milliseconds: 1000));
          if (state?.phase == GamePhase.waitingForPlayers && state!.playerIds.length == 4) {
            _setupNewRound(isFirstRound: true);
          }
        }
      }

      // Determine active turning logic
      if (currentState.phase == GamePhase.preRoundCut) {
        int cutterIdx = (currentState.dealerIndex + 3) % 4;
        String cutterId = currentState.playerIds[cutterIdx];
        if (cutterId.startsWith('bot_')) {
          // Dynamic reaction time: 1-2.5 seconds
          await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(1500)));
          if (state?.phase == GamePhase.preRoundCut) {
            // Cut at a more varied random depth
            int deckSize = currentState.deckCount;
            int cutPoint = deckSize > 6 ? (3 + Random().nextInt(deckSize - 6)) : 1;
            performCut(cutPoint); 
          }
        }
      } else if (currentState.phase == GamePhase.playing) {
        // PROACTIVE DEAL CHECK: If all hands are empty during playing phase, Host must deal.
        bool allHandsEmpty = currentState.handCards.values.every((hand) => hand.isEmpty);
        if (allHandsEmpty) {
           await Future.delayed(const Duration(milliseconds: 1000));
           if (state?.phase == GamePhase.playing && state!.handCards.values.every((hand) => hand.isEmpty)) {
             await dealSubsequentCards();
           }
           // After dealing, the state will change, so we should re-evaluate.
           // If dealSubsequentCards changes the phase, the loop will naturally re-evaluate.
           // If it just deals cards, the next iteration will pick up the new hands.
           continue; 
        }

        final activePlayerId = currentState.playerIds[currentState.currentTurnIndex];
        
        if (activePlayerId.startsWith('bot_')) {
          // Dynamic reaction time: 0.8-2.3 seconds
          await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(1500)));
          if (state?.phase == GamePhase.playing && state!.playerIds[state!.currentTurnIndex] == activePlayerId) {
            _executeBotPlayCard(activePlayerId);
          }
        } else {
          // HUMAN Turner: Handle Auto-Play logic
          
          // 1. Single-Card Auto-Play
          final hand = currentState.handCards[activePlayerId] ?? [];
          if (hand.length == 1) {
             await Future.delayed(const Duration(milliseconds: 1500));
             if (state?.phase == GamePhase.playing && 
                 state!.playerIds[state!.currentTurnIndex] == activePlayerId &&
                 state!.handCards[activePlayerId]?.length == 1) {
                // If it's MY turn and MY client, I play it.
                if (currentUser.uid == activePlayerId) {
                  playCard(activePlayerId, hand.first);
                  return; 
                }
             }
          }

          // 2. Bot Takeover (for offline humans) - ONLY Host does this
          final isOnline = currentState.playerOnlineStatus[activePlayerId] ?? true;
          if (!isOnline) {
             // Host takes over for disconnected player
             await Future.delayed(const Duration(milliseconds: 2000));
             if (state?.phase == GamePhase.playing && 
                 state!.playerIds[state!.currentTurnIndex] == activePlayerId &&
                 state!.playerOnlineStatus[activePlayerId] == false) {
                _executeBotPlayCard(activePlayerId);
                return;
             }
          }

          // 3. Timeout Failsafe (Proactive client-side)
          if (currentState.turnStartTime != null) {
            final elapsed = DateTime.now().difference(currentState.turnStartTime!).inSeconds;
            if (elapsed >= currentState.timerDurationSeconds) {
               // If it's ME, I auto-play because timer expired
               if (currentUser.uid == activePlayerId) {
                 final possibleCards = currentState.handCards[activePlayerId] ?? [];
                 if (possibleCards.isNotEmpty) {
                    playCard(activePlayerId, possibleCards[Random().nextInt(possibleCards.length)]);
                 }
               }
            }
          }
        }
      } else if (currentState.phase == GamePhase.shuffleVoting || currentState.phase == GamePhase.rematchVoting) {
        for (var playerId in currentState.playerIds) {
          if (playerId.startsWith('bot_')) {
            if (currentState.phase == GamePhase.shuffleVoting && !currentState.shuffleVotes.containsKey(playerId)) {
              // Standard bot behavior for memory mode: usually prefers no shuffle (80% chance)
              await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(2000)));
              voteShuffle(playerId, Random().nextDouble() < 0.2); 
            } else if (currentState.phase == GamePhase.rematchVoting && !currentState.rematchVotes.containsKey(playerId)) {
              // Bots always want another round!
              await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(2000)));
              voteRematch(playerId, true);
            }
          }
        }
      }

    } catch (e, stack) {
      debugPrint('CRITICAL ASYNC ERROR in _evaluateBotActions: $e');
      debugPrint('Stack: $stack');
    } finally {
      _isHandlingBotLogic = false;
    }
  }

  void _manageAutoplayTimer(MatchState matchState) {
    _autoplayTimer?.cancel();
    
    if (matchState.phase != GamePhase.playing) return;
    
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    
    final activePlayerId = matchState.playerIds[matchState.currentTurnIndex];
    if (activePlayerId != currentUser.uid) return;
    
    // Calculate remaining time
    if (matchState.turnStartTime != null) {
      final elapsed = DateTime.now().difference(matchState.turnStartTime!).inSeconds;
      final remaining = matchState.timerDurationSeconds - elapsed;
      
      if (remaining <= 0) {
        _triggerAutoplay(matchState, currentUser.uid);
      } else {
        _autoplayTimer = Timer(Duration(seconds: remaining), () {
          if (state?.id == matchState.id) {
            _triggerAutoplay(state!, currentUser.uid);
          }
        });
      }
    }
  }

  void _triggerAutoplay(MatchState matchState, String myUid) {
    if (matchState.phase != GamePhase.playing) return;
    if (matchState.playerIds[matchState.currentTurnIndex] != myUid) return;
    
    final hand = matchState.handCards[myUid] ?? [];
    if (hand.isNotEmpty) {
      playCard(myUid, hand[Random().nextInt(hand.length)]);
    }
  }

  void _executeBotPlayCard(String botId) {
    if (state == null) return;
    final hand = state!.handCards[botId];
    if (hand == null || hand.isEmpty) return;

    final board = state!.board;
    
    // HEURISTIC 1: Can I capture?
    if (board.isNotEmpty) {
      final topRank = board.last.rank;
      final matchingCards = hand.where((c) => c.rank == topRank).toList();
      
      if (matchingCards.isNotEmpty) {
        // TAFWEET STRATEGY: 
        // If in Tafweet mode and I have TWO of this rank, intentionally ignore the capture 
        // now if there's someone else to play after me (baiting a 10/20/30 bonus).
        bool isTafweetMode = state!.mode == GameMode.tafweet;
        if (isTafweetMode && matchingCards.length >= 2 && hand.length > 1) {
           final nonMatching = hand.where((c) => c.rank != topRank).toList();
           if (nonMatching.isNotEmpty) {
             debugPrint('BOT STRATEGY: Baiting Tafweet for ${topRank.name}');
             playCard(botId, nonMatching[Random().nextInt(nonMatching.length)]);
             return;
           }
        }

        // Otherwise, TAKE THE CAPTURE!
        // 5% chance of "human error" (missing a capture)
        if (Random().nextDouble() > 0.05) {
          playCard(botId, matchingCards[Random().nextInt(matchingCards.length)]);
          return;
        }
      }
    }

    // HEURISTIC 2: No capture available, setup for next turn.
    // Try to play a card that I have a duplicate of in my hand.
    final rankCounts = <game_card.Rank, int>{};
    for (var c in hand) {
      rankCounts[c.rank] = (rankCounts[c.rank] ?? 0) + 1;
    }
    final duplicates = hand.where((c) => rankCounts[c.rank]! > 1).toList();
    if (duplicates.isNotEmpty && Random().nextDouble() < 0.7) {
       playCard(botId, duplicates[Random().nextInt(duplicates.length)]);
       return;
    }

    // FALLBACK: Play a random card.
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
        try {
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
        } catch (e, stack) {
          debugPrint('ERROR in joinMatch listener callback: $e');
          debugPrint('Stack: $stack');
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

  Future<void> _setupNewRound({bool isFirstRound = false, bool forceShuffle = false}) async {
    try {
      if (state == null) return;
      
      // Only Host handles deck generation (Security)
      final currentUser = ref.read(currentUserProvider);
      final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
      
      MatchState nextState = state!;
      if (isHost) {
        if (isFirstRound || forceShuffle || state!.roundsSinceLastShuffle >= 5) {
          _secretDeck = Deck.standard();
          _secretDeck!.shuffle();
          nextState = nextState.copyWith(roundsSinceLastShuffle: 0);
        } else {
          _secretDeck = Deck.restoreFromHarvest(state!.harvestStacks);
          nextState = nextState.copyWith(roundsSinceLastShuffle: state!.roundsSinceLastShuffle + 1);
        }
      }

      await _publishState(nextState.copyWith(
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
    } catch (e, stack) {
      debugPrint('ERROR in _setupNewRound: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> performCut(int index) async {
    if (state == null || state!.phase != GamePhase.preRoundCut) return;
    
    // Only Host manages the secret deck
    if (_secretDeck != null) {
      _secretDeck!.cut(index);
      _multimedia.vibrate();
    }

    await _publishState(state!.copyWith(
      deckCount: _secretDeck?.cards.length ?? 0,
      phase: GamePhase.dealingFasha,
    ));
  }

  Future<void> dealInitialCards() async {
  try {
   if (state == null || state!.phase != GamePhase.dealingFasha) return;

   final currentUser = ref.read(currentUserProvider);
   final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
   if (!isHost) return;

   // RECOVERY: If Host refreshed and lost the secret deck, regenerate it
   if (_secretDeck == null) {
      debugPrint('RECOVERY: Host lost secret deck in dealInitialCards. Regenerating.');
      if (state!.roundCount == 1 && state!.roundsSinceLastShuffle == 0) {
         _secretDeck = Deck.standard();
         _secretDeck!.shuffle();
      } else {
         _secretDeck = Deck.restoreFromHarvest(state!.harvestStacks);
      }
      _secretDeck!.cut(Random().nextInt(40) + 5);
   }

   final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
   final board = <game_card.Card>[];

   // Sequential Dealing: Stagger delivery
   // 1. Board (Fasha) - 4 cards
   for (int i = 0; i < 4; i++) {
      final c = _secretDeck?.draw();
      if (c == null) break;
      board.add(c);
      await _publishState(state!.copyWith(board: List.from(board), deckCount: _secretDeck?.cards.length ?? 0));
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
        await _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck?.cards.length ?? 0));
        await Future.delayed(const Duration(milliseconds: 250));
     }
   }

   await _publishState(state!.copyWith(
     recentFasha: List.from(board),
     phase: GamePhase.dealingCards,
   ));

   // 3. Memorization Phase: Wait 5 seconds then start playing
   await Future.delayed(const Duration(seconds: 5));
   
   if (state?.phase == GamePhase.dealingCards) {
     await _publishState(state!.copyWith(
       phase: GamePhase.playing,
       turnStartTime: DateTime.now(),
     ));
   } else if (state?.phase == GamePhase.dealingFasha) {
     // FAILSAFE: If state stuck in fasha but dealing finished
     await _publishState(state!.copyWith(
       phase: GamePhase.playing,
       turnStartTime: DateTime.now(),
     ));
   }
  } catch (e, stack) {
    debugPrint('ERROR in dealInitialCards: $e');
    debugPrint('Stack: $stack');
  }
}

  Future<void> dealSubsequentCards() async {
  try {
   if (state == null) return;
   
   final currentUser = ref.read(currentUserProvider);
   final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
   if (!isHost) return;
   
   // RECOVERY: Minimal mid-round recovery
   if (_secretDeck == null) {
     debugPrint('RECOVERY: Host lost secret deck in dealSubsequentCards. Regenerating.');
     _secretDeck = Deck.restoreFromHarvest(state!.harvestStacks);
     // This might result in duplicate hand cards if we don't subtract them, 
     // but it's better than a hard hang. 
     // Round 1 start is the most common place for this hang.
   }

   if (_secretDeck!.isEmpty) {
      await _handleRoundEnd();
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
        await _publishState(state!.copyWith(handCards: Map.from(hands), deckCount: _secretDeck?.cards.length ?? 0));
        await Future.delayed(const Duration(milliseconds: 250));
     }
   }

   await _publishState(state!.copyWith(
     phase: GamePhase.playing,
     turnStartTime: DateTime.now(),
   ));
  } catch (e, stack) {
    debugPrint('ERROR in dealSubsequentCards: $e');
    debugPrint('Stack: $stack');
  }
}

  Future<void> sendEmoji(String playerId, String emoji) async {
    if (state == null) return;
    final emojis = Map<String, String>.from(state!.playerEmojis);
    emojis[playerId] = emoji;
    _multimedia.vibrate();
    await _publishState(state!.copyWith(playerEmojis: emojis));
  }

  Future<void> clearEmoji(String playerId) async {
    if (state == null) return;
    final emojis = Map<String, String>.from(state!.playerEmojis);
    emojis.remove(playerId);
    await _publishState(state!.copyWith(playerEmojis: emojis));
  }

  Future<void> playCard(String playerId, game_card.Card card) async {
    try {
      if (state == null || state!.phase != GamePhase.playing) return;
      
      // Validate turn
      if (state!.playerIds[state!.currentTurnIndex] != playerId) return;

      // 1. Prepare local state with DEEP COPIES
      final prePlayBoard = List<game_card.Card>.from(state!.board);
      // Deep copy handCards Map and its nested Lists
      final hands = Map<String, List<game_card.Card>>.from(
        state!.handCards.map((k, v) => MapEntry(k, List<game_card.Card>.from(v)))
      );
      // Deep copy harvestStacks Map and its nested Lists
      final harvest = Map<String, List<Capture>>.from(
        state!.harvestStacks.map((k, v) => MapEntry(k, List<Capture>.from(v)))
      );
      // Deep copy skippedMatches Map and its nested Lists
      final skipped = Map<String, List<String>>.from(
        state!.skippedMatches.map((k, v) => MapEntry(k, List<String>.from(v)))
      );
      
      final history = List<game_card.Card>.from(state!.playHistory);
      final ownership = Map<String, String>.from(state!.cardOwnership);
      final emojis = Map<String, String>.from(state!.playerEmojis);
      
      // 0. Detect Skips (Deliberately not capturing)
      if (prePlayBoard.isNotEmpty) {
        final topCard = prePlayBoard.last;
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

      // 1. Remove card from player hand
      hands[playerId]?.remove(card);

      // 2. Calculate capture
      final capturedCards = GameEngineUtils.calculateCapture(card, prePlayBoard);
      final teamId = _getTeamOfPlayer(playerId);
      
      if (!harvest.containsKey(teamId)) {
        harvest[teamId] = [];
      }

      int pointsEarned = 0;
      int nextTurn = (state!.currentTurnIndex + 1) % 4;
      List<game_card.Card> finalBoard = List.from(prePlayBoard);

      if (capturedCards.isEmpty) {
        finalBoard.add(card);
        ownership[card.firebaseKey] = playerId;
      } else {
        pointsEarned = 1; 
        
        bool isTafweetMode = state!.mode == GameMode.tafweet;
        if (isTafweetMode) {
          final playerSkips = List<String>.from(skipped[playerId] ?? []);
          final previousPlayerId = state!.playerIds[(state!.currentTurnIndex + 3) % 4];
          
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
          
          // Auto-clear emoji after duration
          if (emojis.containsKey(playerId)) {
            Future.delayed(const Duration(seconds: 3), () => clearEmoji(playerId));
          }
        }

        final harvestedBoardCards = List<game_card.Card>.from(capturedCards)..remove(card);
        for (var c in harvestedBoardCards) {
          finalBoard.remove(c);
        }
        
        harvest[teamId]?.add(Capture(
          leadingCard: card,
          capturedCards: harvestedBoardCards,
        ));
        _multimedia.playSfx('sfx/capture.mp3');
      }
      _multimedia.vibrate();
      
      // 3. Update Play History
      history.add(card);
      if (history.length > 10) history.removeAt(0);

      // 4. Update state atomically
      final allHandsEmpty = hands.values.every((hand) => hand.isEmpty);

      await _publishState(state!.copyWith(
        board: finalBoard,
        handCards: hands,
        harvestStacks: harvest,
        skippedMatches: skipped,
        playHistory: history,
        cardOwnership: ownership,
        playerEmojis: emojis, // Unified emoji update
        currentTurnIndex: nextTurn,
        teamAScore: state!.teamAScore + (teamId == 'teamA' ? pointsEarned : 0),
        teamBScore: state!.teamBScore + (teamId == 'teamB' ? pointsEarned : 0),
        lastCaptureTeam: pointsEarned > 0 ? teamId : state!.lastCaptureTeam,
        turnStartTime: DateTime.now(),
      ));

      if (allHandsEmpty) {
        await dealSubsequentCards();
      }
    } catch (e, stack) {
      debugPrint('ERROR in playCard: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> _handleRoundEnd() async {
    try {
      if (state == null) return;
       
      final harvest = Map<String, List<Capture>>.from(state!.harvestStacks);
      final board = List<game_card.Card>.from(state!.board);
      
      // Last Capture Rule
      if (board.isNotEmpty && state!.lastCaptureTeam != null) {
         harvest[state!.lastCaptureTeam!]?.add(Capture(
           leadingCard: board.first, // Placeholder for rules consistency
           capturedCards: board.skip(1).toList(),
         ));
      }

      // Al-Ard (Majority capture points logic)
      int pointsA = state!.teamAScore;
      int pointsB = state!.teamBScore;
      
      int teamACaptureCount = harvest['teamA']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;
      int teamBCaptureCount = harvest['teamB']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;

      if (teamACaptureCount > teamBCaptureCount) {
         pointsA += 3;
      } else if (teamBCaptureCount > teamACaptureCount) {
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
         await _publishState(endPhase.copyWith(
            phase: GamePhase.rematchVoting,
            skippedMatches: {},
            playHistory: [],
         ));
      } else {
         // Rotate dealer, trigger UI prompt for Shuffle/No-Shuffle
         await _publishState(endPhase.copyWith(
            dealerIndex: (endPhase.dealerIndex + 1) % 4,
            phase: GamePhase.shuffleVoting,
            skippedMatches: {},
            playHistory: [],
         ));
      }
    } catch (e, stack) {
      debugPrint('ERROR in _handleRoundEnd: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> voteShuffle(String playerId, bool wantsShuffle) async {
     if (state == null || state!.phase != GamePhase.shuffleVoting) return;
     
     final votes = Map<String, bool>.from(state!.shuffleVotes);
     votes[playerId] = wantsShuffle;
     
     MatchState newState = state!.copyWith(shuffleVotes: votes);
     
     // Check if all 4 players voted
     if (votes.length == 4) {
        // If anyone voted yes, force shuffle (Memory Mode broken)
        bool forceShuffle = votes.values.any((v) => v == true);
        state = newState; 
        await _setupNewRound(forceShuffle: forceShuffle);
     } else {
        await _publishState(newState);
     }
  }

  Future<void> voteRematch(String playerId, bool wantsRematch) async {
     if (state == null || state!.phase != GamePhase.rematchVoting) return;
     
     final votes = Map<String, bool>.from(state!.rematchVotes);
     votes[playerId] = wantsRematch;
     
     MatchState newState = state!.copyWith(rematchVotes: votes);
     
     if (votes.length == 4) {
        bool unanimous = votes.values.every((v) => v == true);
        if (unanimous) {
           // Reset Match Completely
           await _publishState(newState.copyWith(
              teamAScore: 0,
              teamBScore: 0,
              roundCount: 1,
              roundsSinceLastShuffle: 0,
              consecutiveTafweetCount: 0,
              rematchVotes: {},
              shuffleVotes: {},
           ));
           await _setupNewRound(isFirstRound: true);
        } else {
           // End Match completely
           await _publishState(newState.copyWith(phase: GamePhase.matchOver));
        }
     } else {
        await _publishState(newState);
     }
  }

  String _getTeamOfPlayer(String playerId) {
    int index = state!.playerIds.indexOf(playerId);
    return (index == 0 || index == 2) ? 'teamA' : 'teamB';
  }
}

final matchStateProvider = StateNotifierProvider<MatchStateNotifier, MatchState?>((ref) {
  // Watch multimedia service to ensure it's available for triggers
  ref.watch(multimediaServiceProvider); 
  return MatchStateNotifier(ref);
});
