import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import 'package:quiver/async.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/capture.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine_utils.dart';
import '../../data/repositories/multiplayer_sync_service.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:halabessa/core/services/multimedia_service.dart';

final multiplayerSyncServiceProvider = Provider<MultiplayerSyncService>((ref) {
  // Use a singleton pattern or standard instance to avoid repeat initialization errors
  final db = FirebaseDatabase.instance;
  // If a custom URL is strictly needed, it should be set once in main.dart or here with a check.
  // For Halabessa, we use the default RTDB from the google-services/FirebaseOptions.
  return MultiplayerSyncService(db);
});

final localPlayOriginsProvider = StateProvider<Map<String, Offset>>((ref) => {});

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
  StreamSubscription<CountdownTimer>? _autoplaySubscription;
  final Map<String, StreamSubscription<CountdownTimer>> _tafweetSubscriptions = {};
  
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
    _autoplaySubscription?.cancel();
    _autoplaySubscription = null;
    for (var sub in _tafweetSubscriptions.values) {
      sub.cancel();
    }
    _tafweetSubscriptions.clear();
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
                   final currentState = state;
                   if (currentState != null) _evaluateBotActions(currentState);
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

       // Calculate spectators: those in presence map but not in playerIds
       int currentSpectators = 0;
       presence.forEach((uid, isOnline) {
         if (isOnline && !serverState.playerIds.contains(uid)) {
           currentSpectators++;
         }
       });

       if (serverState.spectatorCount != currentSpectators) {
         changed = true;
       }

       if (changed) {
         _publishState(serverState.copyWith(
           playerOnlineStatus: newOnlineStatus,
           spectatorCount: currentSpectators,
         ));
       }
    });
  }

  void rebind(String matchId) {
    if (lastBoundMatchId == matchId && state != null) return;
    bindToMatch(matchId);
  }

  Future<void> _evaluateBotActions(MatchState serverState) async {
    if (_isHandlingBotLogic) return;
    _isHandlingBotLogic = true;

    // Determine if the LOCAL client is the Host (index 0) of the match.
    // We only want ONE client (the Host) to execute Bot logic to prevent duplicate Firebase writes.
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || serverState.playerIds.isEmpty) {
      _isHandlingBotLogic = false;
      return;
    }
    
    final isHost = serverState.playerIds.indexOf(currentUser.uid) == 0;
    if (!isHost) {
      _isHandlingBotLogic = false;
      return;
    }

    // Safety delay to allow state to settle
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final currentState = serverState;
      if (currentState.playerIds.isEmpty) return;
      // Host specific global phase handling (Dealing Cards)
      if (currentState.phase == GamePhase.dealingFasha) {
        // This is where Host deals Initial Board + Hands
        final currentState = state;
        if (currentState != null && currentState.phase == GamePhase.dealingFasha) {
          await dealInitialCards();
        }
      } else if (currentState.phase == GamePhase.waitingForPlayers) {
        // LOBBY AUTO-START: If 4 REAL players join, Host triggers start automatically.
        final humanCount = currentState.playerIds.where((id) => !id.startsWith('waiting_')).toList().length;
        if (humanCount == 4) {
          await Future.delayed(const Duration(milliseconds: 1000));
          final finalState = state;
          if (finalState != null && finalState.phase == GamePhase.waitingForPlayers && 
              finalState.playerIds.where((id) => !id.startsWith('waiting_')).length == 4) {
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
          final finalState = state;
          if (finalState != null && finalState.phase == GamePhase.preRoundCut) {
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
            final finalState = state;
            if (finalState != null && finalState.phase == GamePhase.playing && finalState.handCards.values.every((hand) => hand.isEmpty)) {
              await dealSubsequentCards();
            }
            return; 
         }

        final activePlayerId = currentState.playerIds[currentState.currentTurnIndex];
        
        if (activePlayerId.startsWith('bot_')) {
          // Dynamic reaction time: 0.8-2.3 seconds
          await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(1500)));
          final finalState = state;
          if (finalState != null && finalState.phase == GamePhase.playing && finalState.playerIds[finalState.currentTurnIndex] == activePlayerId) {
            _executeBotPlayCard(activePlayerId);
          }
        } else {
          // HUMAN Turner: Handle Auto-Play logic
          
          // 1. Single-Card Auto-Play
          final hand = currentState.handCards[activePlayerId] ?? [];
          if (hand.length == 1) {
              await Future.delayed(const Duration(milliseconds: 1500));
              final finalState = state;
              if (finalState != null && 
                  finalState.phase == GamePhase.playing && 
                  finalState.playerIds[finalState.currentTurnIndex] == activePlayerId &&
                  finalState.handCards[activePlayerId]?.length == 1) {
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
              final finalState = state;
              if (finalState != null && 
                  finalState.phase == GamePhase.playing && 
                  finalState.playerIds[finalState.currentTurnIndex] == activePlayerId &&
                  finalState.playerOnlineStatus[activePlayerId] == false) {
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
        // 1. Bot Voting Logic
        for (var playerId in currentState.playerIds) {
          if (playerId.startsWith('bot_')) {
            if (currentState.phase == GamePhase.shuffleVoting && !currentState.shuffleVotes.containsKey(playerId)) {
              // Bot follows human majority or votes random if draw/no human votes
              await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1500)));
              
              final currentVotes = state?.shuffleVotes ?? {}; // Use current state
              final humanVotes = currentVotes.entries
                  .where((e) => !e.key.startsWith('bot_'))
                  .map((e) => e.value)
                  .toList();
              
              bool botChoice;
              if (humanVotes.isEmpty) {
                botChoice = Random().nextDouble() < 0.2; // Default 20% shuffle
              } else {
                int yesCount = humanVotes.where((v) => v == true).length;
                int noCount = humanVotes.length - yesCount;
                if (yesCount > noCount) {
                  botChoice = true;
                } else if (noCount > yesCount) {
                  botChoice = false;
                } else {
                  botChoice = Random().nextBool();
                }
              }
              
              voteShuffle(playerId, botChoice); 
            } else if (currentState.phase == GamePhase.rematchVoting && !currentState.rematchVotes.containsKey(playerId)) {
              // Rematch: Bots follow human majority for rematch too
              await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1500)));
              
              final currentVotes = state?.rematchVotes ?? {}; // Use current state
              final humanVotes = currentVotes.entries
                  .where((e) => !e.key.startsWith('bot_'))
                  .map((e) => e.value)
                  .toList();
              
              bool botChoice;
              if (humanVotes.isEmpty) {
                botChoice = true; // Bots like playing!
              } else {
                int yesCount = humanVotes.where((v) => v == true).length;
                int noCount = humanVotes.length - yesCount;
                if (yesCount > noCount) {
                  botChoice = true;
                } else if (noCount > yesCount) {
                  botChoice = false;
                } else {
                  botChoice = true; // Tie-breaker: bots want to play
                }
              }
              
              voteRematch(playerId, botChoice);
            }
          }
        }

        // 2. Host Transition Logic (Trigger if votes complete or short-circuited)
        if (currentState.phase == GamePhase.shuffleVoting) {
           final votes = currentState.shuffleVotes;
           bool anyoneVotedNo = votes.values.any((v) => v == false);
           if (anyoneVotedNo || votes.length == 4) {
             await _setupNewRound(forceShuffle: !anyoneVotedNo && votes.values.any((v) => v == true));
           }
        } else if (currentState.phase == GamePhase.rematchVoting) {
           final votes = currentState.rematchVotes;
           if (votes.length == 4) {
             bool unanimous = votes.values.every((v) => v == true);
             if (unanimous) {
                // ... Reset logic handled in voteRematch currently, 
                // but let's move it to host logic for safety if needed.
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
    _autoplaySubscription?.cancel();
    _autoplaySubscription = null;
    
    if (matchState.phase != GamePhase.playing) return;
    
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    
    final activePlayerId = matchState.playerIds[matchState.currentTurnIndex];
    if (activePlayerId != currentUser.uid) return;
    
    if (matchState.turnStartTime != null) {
      final elapsed = DateTime.now().difference(matchState.turnStartTime!).inSeconds;
      final remaining = matchState.timerDurationSeconds - elapsed;
      
      if (remaining <= 0) {
        _triggerAutoplay(matchState, currentUser.uid);
      } else {
        // Use quiver's CountdownTimer for more robust tracking
        final timer = CountdownTimer(
          Duration(seconds: remaining),
          const Duration(seconds: 1),
        );
        _autoplaySubscription = timer.listen(
          (t) => {}, // Each tick could update local UI state if needed
          onDone: () {
            final currentState = state;
            if (currentState != null && currentState.id == matchState.id) {
              _triggerAutoplay(currentState, currentUser.uid);
            }
          },
        );
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
        final currentState = state;
        if (currentState == null) return;
        final hand = currentState.handCards[botId];
        if (hand == null || hand.isEmpty) return;

        final board = currentState.board;
        
        // HEURISTIC 1: Can I capture?
        if (board.isNotEmpty) {
          final topRank = board.last.rank;
          final matchingCards = hand.where((c) => c.rank == topRank).toList();
          
          if (matchingCards.isNotEmpty) {
            bool isTafweetMode = currentState.mode == GameMode.tafweet;
        if (isTafweetMode && matchingCards.length >= 2 && hand.length > 1) {
           final nonMatching = hand.where((c) => c.rank != topRank).toList();
           if (nonMatching.isNotEmpty) {
             // debugPrint('BOT STRATEGY: Baiting Tafweet for ${topRank.name}');
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

  void initializeMatch(String playerId, String displayName, GameMode mode, {int maxPoints = 41, int timerDurationSeconds = 10, bool isPublic = false}) {
    final newId = _generateRoomId();
    // Initialize with only the host. The UI/Joining logic will handle seats.
    final initial = MatchState(
      id: newId,
      mode: mode,
      maxPoints: maxPoints,
      isPublic: isPublic,
      playerIds: [playerId, "waiting_1", "waiting_2", "waiting_3"],
      playerNames: {playerId: displayName},
      dealerIndex: 0,
      currentTurnIndex: 1, 
      phase: GamePhase.waitingForPlayers,
      timerDurationSeconds: timerDurationSeconds,
    );
    ref.read(multiplayerSyncServiceProvider).createMatch(initial);
    state = initial;
    bindToMatch(newId);
  }

  void spectateMatch(String matchId) {
    bindToMatch(matchId);
  }

  Future<void> joinMatch(String matchId, String playerId, String displayName) async {
    final dbRef = FirebaseDatabase.instance.ref('matches/$matchId');
    final snapshot = await dbRef.get();
    if (snapshot.exists) {
      final json = Map<String, dynamic>.from(snapshot.value as Map);
      final playerIds = List<String>.from(json['playerIds'] ?? []);
      final playerNames = Map<String, String>.from(json['playerNames'] ?? {});
      
      if (playerIds.contains(playerId)) {
        bindToMatch(matchId);
        return;
      }

      int targetIdx = -1;
      // Prioritize partner slot (index 2) for second human as requested
      if (playerIds.length >= 3 && playerIds[2].startsWith('waiting_')) {
        targetIdx = 2;
      } else {
        // Find first available waiting slot
        for (int i = 0; i < playerIds.length; i++) {
          if (playerIds[i].startsWith('waiting_')) {
            targetIdx = i;
            break;
          }
        }
      }

      if (targetIdx != -1) {
        playerIds[targetIdx] = playerId;
        playerNames[playerId] = displayName;
        await dbRef.update({
          'playerIds': playerIds,
          'playerNames': playerNames,
        });
        bindToMatch(matchId);
      }
    }
  }

  Future<void> voteForBots(String playerId) async {
    final currentState = state;
    if (currentState == null || currentState.phase != GamePhase.waitingForPlayers) return;
    
    final votes = Map<String, bool>.from(currentState.botInjectionVotes);
    votes[playerId] = true;
    
    // Count human players currently in the room
    final humanIds = currentState.playerIds.where((id) => !id.startsWith('waiting_')).toList();
    final humanCount = humanIds.length;
    
    if (votes.length >= humanCount) {
      // All present humans agreed, fill the rest with bots
      final newPlayerIds = List<String>.from(currentState.playerIds);
      final newPlayerNames = Map<String, String>.from(currentState.playerNames);
      
      for (int i = 0; i < newPlayerIds.length; i++) {
        if (newPlayerIds[i].startsWith('waiting_')) {
          final botId = 'bot_${i + 1}';
          newPlayerIds[i] = botId;
          newPlayerNames[botId] = 'player_default_name'; // Key for translation
        }
      }
      
      await _publishState(currentState.copyWith(
        playerIds: newPlayerIds,
        playerNames: newPlayerNames,
        botInjectionVotes: votes,
      ));
    } else {
      await _publishState(currentState.copyWith(botInjectionVotes: votes));
    }
  }

  Future<void> _setupNewRound({bool isFirstRound = false, bool forceShuffle = false}) async {
    try {
      final currentState = state;
      if (currentState == null) return;
      
      // CRITICAL: Ensure we don't start with placeholders!
      if (currentState.playerIds.any((id) => id.startsWith('waiting_'))) {
        debugPrint('ABORT: Attempted to start round with placeholders in playerIds');
        return;
      }

      final currentUser = ref.read(currentUserProvider);
      final isHost = currentState.playerIds.indexOf(currentUser?.uid ?? '') == 0;
      
      MatchState nextState = currentState;
      if (isHost) {
        if (isFirstRound || forceShuffle || currentState.roundsSinceLastShuffle >= 5) {
          _secretDeck = Deck.standard();
          _secretDeck!.shuffle();
          nextState = nextState.copyWith(roundsSinceLastShuffle: 0);
        } else {
          _secretDeck = Deck.restoreFromHarvest(currentState.harvestStacks);
          nextState = nextState.copyWith(roundsSinceLastShuffle: currentState.roundsSinceLastShuffle + 1);
        }
        
        final dealerIdx = isFirstRound ? 0 : (currentState.phase == GamePhase.shuffleVoting ? currentState.dealerIndex : (currentState.dealerIndex + 1) % 4);

        await _publishState(nextState.copyWith(
          deckCount: _secretDeck?.cards.length ?? 0,
          board: [],
          recentFasha: [],
          handCards: { for (var id in currentState.playerIds) id: [] },
          harvestStacks: { 'teamA': [], 'teamB': [] },
          skippedMatches: {},
          playHistory: [],
          shuffleVotes: {},
          rematchVotes: {},
          phase: GamePhase.preRoundCut,
          roundCount: currentState.roundCount + (isFirstRound ? 0 : 1),
          dealerIndex: dealerIdx,
          cardOwnership: {},
        ));
      }
    } catch (e, stack) {
      debugPrint('ERROR in _setupNewRound: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> performCut(int index) async {
    final currentState = state;
    if (currentState == null || currentState.phase != GamePhase.preRoundCut) return;
    
    if (_secretDeck != null) {
      _secretDeck!.cut(index);
      _multimedia.vibrate();
    }

    final lastCard = _secretDeck?.cards.first;

    await _publishState(currentState.copyWith(
      deckCount: _secretDeck?.cards.length ?? 0,
      phase: GamePhase.dealingFasha, 
      cutLastCard: lastCard,
    ));

    Future.delayed(const Duration(seconds: 2), () {
      if (state?.id == currentState.id && state?.phase == GamePhase.dealingFasha) {
         state = state?.copyWith(cutLastCard: null);
         dealInitialCards();
      }
    });
  }

  Future<void> dealInitialCards() async {
  try {
    final currentState = state;
    if (currentState == null || currentState.phase != GamePhase.dealingFasha) return;

    final currentUser = ref.read(currentUserProvider);
    final isHost = state!.playerIds.indexOf(currentUser?.uid ?? '') == 0;
    if (!isHost) return;

    if (_secretDeck == null) {
      _secretDeck = Deck.standard();
      _secretDeck!.shuffle();
      _secretDeck!.cut(Random().nextInt(40) + 5);
    }

    final hands = Map<String, List<game_card.Card>>.from(state!.handCards);
    final board = <game_card.Card>[];

    // Consolidated Dealing: 1. Board
    for (int i = 0; i < 4; i++) {
      final c = _secretDeck?.draw();
      if (c == null) break;
      board.add(c);
    }
    _multimedia.playSfx('sfx/deal.mp3');
    await _publishState(state!.copyWith(board: List.from(board), deckCount: _secretDeck?.cards.length ?? 0));
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Players
    for (var playerId in state!.playerIds) {
      final playerHand = <game_card.Card>[];
      for (int i = 0; i < 4; i++) {
        final c = _secretDeck?.draw();
        if (c == null) break;
        playerHand.add(c);
      }
      hands[playerId] = List.from(playerHand);
    }
    
    await _publishState(state!.copyWith(
      handCards: Map.from(hands),
      deckCount: _secretDeck?.cards.length ?? 0,
      recentFasha: List.from(board),
      phase: GamePhase.dealingCards,
    ));

    await Future.delayed(const Duration(seconds: 5));
    
    if (state?.phase == GamePhase.dealingCards) {
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

   final finalState = state;
   if (finalState != null) {
     await _publishState(finalState.copyWith(
       phase: GamePhase.playing,
       turnStartTime: DateTime.now(),
     ));
   }
  } catch (e, stack) {
    debugPrint('ERROR in dealSubsequentCards: $e');
    debugPrint('Stack: $stack');
  }
}

  Future<void> sendEmoji(String playerId, String emoji) async {
    final currentState = state;
    if (currentState == null) return;
    final emojis = Map<String, String>.from(currentState.playerEmojis);
    emojis[playerId] = emoji;
    _multimedia.vibrate();
    await _publishState(currentState.copyWith(playerEmojis: emojis));
  }

  Future<void> clearEmoji(String playerId) async {
    final currentState = state;
    if (currentState == null) return;
    final emojis = Map<String, String>.from(currentState.playerEmojis);
    emojis.remove(playerId);
    await _publishState(currentState.copyWith(playerEmojis: emojis));
  }

  Future<void> playCard(String playerId, game_card.Card card, {Offset? origin}) async {
    try {
      final currentState = state;
      if (currentState == null || currentState.phase != GamePhase.playing) return;
      
      if (origin != null) {
        ref.read(localPlayOriginsProvider.notifier).update((m) => {...m, card.firebaseKey: origin});
      }

      // Validate turn
      if (currentState.playerIds[currentState.currentTurnIndex] != playerId) return;

      // 1. Prepare local state with DEEP COPIES
      final prePlayBoard = List<game_card.Card>.from(currentState.board);
      // Deep copy handCards Map and its nested Lists
      final hands = Map<String, List<game_card.Card>>.from(
        currentState.handCards.map((k, v) => MapEntry(k, List<game_card.Card>.from(v)))
      );
      // Deep copy harvestStacks Map and its nested Lists
      final harvest = Map<String, List<Capture>>.from(
        currentState.harvestStacks.map((k, v) => MapEntry(k, List<Capture>.from(v)))
      );
      // Deep copy skippedMatches Map and its nested Lists
      final skipped = Map<String, List<String>>.from(
        currentState.skippedMatches.map((k, v) => MapEntry(k, List<String>.from(v)))
      );
      
      final history = List<game_card.Card>.from(currentState.playHistory);
      final ownership = Map<String, String>.from(currentState.cardOwnership);
      final emojis = Map<String, String>.from(currentState.playerEmojis);
      
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
            
            // Start a Tafweet window timer (e.g. 45s) using quiver
            _startTafweetExpiry(playerId, skipKey, const Duration(seconds: 45));
          }
        }
      }

      // 1. Remove card from player hand (Use firebaseKey for robust removal)
      hands[playerId]?.removeWhere((c) => c.firebaseKey == card.firebaseKey);
      final allHandsEmpty = hands.values.every((hand) => hand.isEmpty);

      // 2. Calculate capture
      final capturedCards = GameEngineUtils.calculateCapture(card, prePlayBoard);
      final teamId = _getTeamOfPlayer(playerId);
      
      if (!harvest.containsKey(teamId)) {
        harvest[teamId] = [];
      }

      int pointsEarned = 0;
      int nextTurn = (currentState.currentTurnIndex + 1) % 4;
      List<game_card.Card> finalBoard = List.from(prePlayBoard);

      if (capturedCards.isEmpty) {
        finalBoard.add(card);
        ownership[card.firebaseKey] = playerId;

        await _publishState(currentState.copyWith(
          board: finalBoard,
          handCards: hands,
          skippedMatches: skipped,
          playHistory: history,
          cardOwnership: ownership,
          currentTurnIndex: nextTurn,
          turnStartTime: DateTime.now(),
        ));
      } else {
        pointsEarned = 1; 
        
        // 1. Enter Capturing Phase (Visually hold cards on board)
        finalBoard.add(card); // Add the card that triggered the capture
        ownership[card.firebaseKey] = playerId;

        await _publishState(currentState.copyWith(
          board: finalBoard,
          handCards: hands,
          phase: GamePhase.capturing,
          capturingCards: List.from(capturedCards),
          capturingTeam: teamId,
          capturingStage: 0, // Merge stage
          cardOwnership: ownership,
          playerEmojis: emojis,
        ));

        _multimedia.playSfx('sfx/capture.mp3');
        _multimedia.vibrate();

        // Stage 1: Symmetric Merge (0.8s)
        await Future.delayed(const Duration(milliseconds: 800));

        // Stage 2: Fly to Box (0.8s)
        final s = state;
        if (s != null) {
          await _publishState(s.copyWith(capturingStage: 1));
        }
        await Future.delayed(const Duration(milliseconds: 800));

        // 3. Finalize Harvest
        bool isTafweetMode = currentState.mode == GameMode.tafweet;
        if (isTafweetMode) {
          final playerSkips = List<String>.from(skipped[playerId] ?? []);
          final previousPlayerId = currentState.playerIds[(currentState.currentTurnIndex + 3) % 4];
          
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
          
          if (emojis.containsKey(playerId)) {
            Future.delayed(const Duration(seconds: 3), () => clearEmoji(playerId));
          }
        }

        final harvestedBoardCards = List<game_card.Card>.from(capturedCards)..removeWhere((c) => c.firebaseKey == card.firebaseKey);
        final keysToRemove = capturedCards.map((c) => c.firebaseKey).toSet();
        finalBoard.removeWhere((c) => keysToRemove.contains(c.firebaseKey));
        
        harvest[teamId]?.add(Capture(
          leadingCard: card,
          capturedCards: harvestedBoardCards,
        ));

        await _publishState(currentState.copyWith(
          board: finalBoard,
          handCards: hands,
          harvestStacks: harvest,
          skippedMatches: skipped,
          playHistory: history,
          cardOwnership: ownership,
          playerEmojis: emojis,
          phase: GamePhase.playing, // Back to playing
          capturingCards: [],
          capturingTeam: null,
          currentTurnIndex: nextTurn,
          teamAScore: currentState.teamAScore + (teamId == 'teamA' ? pointsEarned : 0),
          teamBScore: currentState.teamBScore + (teamId == 'teamB' ? pointsEarned : 0),
          lastCaptureTeam: teamId,
          turnStartTime: DateTime.now(),
        ));
      }

      if (allHandsEmpty && currentState.phase != GamePhase.capturing) {
        await dealSubsequentCards();
      } else if (allHandsEmpty) {
        // If we captured and it was the last card, wait a bit more for the final cleanup
        await Future.delayed(const Duration(milliseconds: 500));
        await dealSubsequentCards();
      }
    } catch (e, stack) {
      debugPrint('ERROR in playCard: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> _handleRoundEnd() async {
    try {
      final currentState = state;
      if (currentState == null) return;
       
      final harvest = Map<String, List<Capture>>.from(currentState.harvestStacks);
      final board = List<game_card.Card>.from(currentState.board);
      
      // Last Capture Rule
      if (board.isNotEmpty && currentState.lastCaptureTeam != null) {
         harvest[currentState.lastCaptureTeam!]?.add(Capture(
           leadingCard: board.first, // Placeholder for rules consistency
           capturedCards: board.skip(1).toList(),
         ));
      }

      // Al-Ard (Majority capture points logic)
      int pointsA = currentState.teamAScore;
      int pointsB = currentState.teamBScore;
      
      int teamACaptureCount = harvest['teamA']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;
      int teamBCaptureCount = harvest['teamB']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;

      if (teamACaptureCount > teamBCaptureCount) {
         pointsA += 3;
      } else if (teamBCaptureCount > teamACaptureCount) {
         pointsB += 3;
      }

      MatchState endPhase = currentState.copyWith(
         board: [],
         teamAScore: pointsA,
         teamBScore: pointsB,
         phase: GamePhase.roundScoring,
      );
      
      // Check Match Win Condition
     if (pointsA >= endPhase.maxPoints || pointsB >= endPhase.maxPoints) {
          final winnerTeam = pointsA >= endPhase.maxPoints ? 'teamA' : 'teamB';
          _updateUserStatsAfterMatch(winnerTeam, pointsA, pointsB);

          // Play End Match SFX
          final currentUser = ref.read(currentUserProvider);
          if (currentUser != null) {
            final myTeam = _getTeamOfPlayer(currentUser.uid);
            if (myTeam == winnerTeam) {
              _multimedia.playSfx('sfx/win.mp3');
            } else {
              _multimedia.playSfx('sfx/lose.mp3');
            }
          }

          await _publishState(endPhase.copyWith(
             phase: GamePhase.rematchVoting,
             skippedMatches: {},
             playHistory: [],
          ));
      } else {
         // SHUFFLE LOGIC REFINEMENT:
         // 1. If we reached 6 rounds without shuffle (roundsSinceLastShuffle >= 5), FORCE SHUFFLE.
         // 2. If we reached 3 rounds (roundsSinceLastShuffle >= 2), ASK FOR SHUFFLE.
         // 3. Otherwise, just deal next round.
         
         if (endPhase.roundsSinceLastShuffle >= 5) {
// debugPrint('SHUFFLE: Forced shuffle triggered (6th round).');
            await _setupNewRound(forceShuffle: true);
         } else if (endPhase.roundsSinceLastShuffle >= 2) {
            // Rotate dealer, trigger UI prompt for Shuffle/No-Shuffle
            await _publishState(endPhase.copyWith(
               dealerIndex: (endPhase.dealerIndex + 1) % 4,
               phase: GamePhase.shuffleVoting,
               skippedMatches: {},
               playHistory: [],
            ));
         } else {
// debugPrint('SHUFFLE: Skipping vote, moving to round ${endPhase.roundCount + 1}');
            await _setupNewRound(forceShuffle: false);
         }
      }
    } catch (e, stack) {
      debugPrint('ERROR in _handleRoundEnd: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> voteShuffle(String playerId, bool wantsShuffle) async {
     final currentState = state;
     if (currentState == null || currentState.phase != GamePhase.shuffleVoting) return;
     
     final votes = Map<String, bool>.from(currentState.shuffleVotes);
     votes[playerId] = wantsShuffle;
     
     MatchState newState = currentState.copyWith(shuffleVotes: votes);
     
     // ALWAYS publish vote for others to see
     await _publishState(newState);

     final currentUser = ref.read(currentUserProvider);
     final isHost = currentUser != null && currentState.playerIds.indexOf(currentUser.uid) == 0;

      // VETO RULE: If anyone votes "No", the shuffle is cancelled immediately.
      // Otherwise, we wait for all 4 players to vote "Yes".
      if (isHost) {
         if (wantsShuffle == false) {
            // Unilateral Veto
            await _setupNewRound(forceShuffle: false);
         } else if (votes.length == 4) {
            // All voted, check if all are Yes
            bool allYes = votes.values.every((v) => v == true);
            await _setupNewRound(forceShuffle: allYes);
         }
      }
  }

  Future<void> voteRematch(String playerId, bool wantsRematch) async {
     final currentState = state;
     if (currentState == null || currentState.phase != GamePhase.rematchVoting) return;
     
     final votes = Map<String, bool>.from(currentState.rematchVotes);
     votes[playerId] = wantsRematch;
     
     MatchState newState = currentState.copyWith(rematchVotes: votes);
     
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

  void _startTafweetExpiry(String playerId, String skipKey, Duration duration) {
    final subKey = '$playerId:$skipKey';
    _tafweetSubscriptions[subKey]?.cancel();
    
    final timer = CountdownTimer(duration, const Duration(seconds: 5));
    _tafweetSubscriptions[subKey] = timer.listen(null, onDone: () {
      _handleTafweetExpiry(playerId, skipKey);
    });
  }

  void _handleTafweetExpiry(String playerId, String skipKey) {
    final currentState = state;
    if (currentState == null) return;
    
    final skipped = Map<String, List<String>>.from(
      currentState.skippedMatches.map((k, v) => MapEntry(k, List<String>.from(v)))
    );
    
    if (skipped[playerId]?.contains(skipKey) == true) {
      skipped[playerId]?.remove(skipKey);
      _publishState(currentState.copyWith(skippedMatches: skipped));
// debugPrint('TAFWEET: Skip $skipKey for $playerId expired.');
    }
  }

  String _getTeamOfPlayer(String playerId) {
    final currentState = state;
    if (currentState == null) return 'teamA';
    int index = currentState.playerIds.indexOf(playerId);
    return (index == 0 || index == 2) ? 'teamA' : 'teamB';
  }

  Future<void> _updateUserStatsAfterMatch(String winnerTeam, int scoreA, int scoreB) async {
    final currentState = state;
    if (currentState == null) return;

    final currentUser = ref.read(currentUserProvider);
    final isHost = currentUser != null && currentState.playerIds.indexOf(currentUser.uid) == 0;
    
    // Only Host records stats in Firestore to prevent duplicate writes
    if (!isHost) return;

// debugPrint('FIRESTORE: Recording match stats for winner $winnerTeam');

    for (int i = 0; i < currentState.playerIds.length; i++) {
      final playerId = currentState.playerIds[i];
      if (playerId.startsWith('bot_')) continue;

      final playerTeam = (i == 0 || i == 2) ? 'teamA' : 'teamB';
      final isWinner = playerTeam == winnerTeam;
      final myTeamScore = playerTeam == 'teamA' ? scoreA : scoreB;

      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(playerId);
        
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final currentPoints = data['points'] ?? 0;
            final currentWins = data['wins'] ?? 0;
            final currentLosses = data['losses'] ?? 0;
            final currentGames = data['gamesPlayed'] ?? 0;
            final currentBest = data['bestScore'] ?? 0;

            transaction.update(userRef, {
              'points': currentPoints + (isWinner ? 100 : 20), // 100 for win, 20 for loss
              'wins': currentWins + (isWinner ? 1 : 0),
              'losses': currentLosses + (isWinner ? 0 : 1),
              'gamesPlayed': currentGames + 1,
              'bestScore': myTeamScore > currentBest ? myTeamScore : currentBest,
            });
          }
        });
      } catch (e) {
        debugPrint('ERROR updating stats for $playerId: $e');
      }
    }
  }
}

final matchStateProvider = StateNotifierProvider<MatchStateNotifier, MatchState?>((ref) {
  // Watch multimedia service to ensure it's available for triggers
  ref.watch(multimediaServiceProvider); 
  return MatchStateNotifier(ref);
});
