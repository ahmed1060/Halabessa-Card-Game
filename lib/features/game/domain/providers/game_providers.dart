import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import 'package:quiver/async.dart';
import '../../domain/models/match_state.dart';
import '../../domain/models/room_summary.dart';
import '../../domain/models/capture.dart';
import '../../domain/models/card.dart' as game_card;
import '../../domain/models/game_action.dart';
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine.dart';
import '../../domain/logic/bot_brain.dart';
import '../../domain/logic/score_config.dart';
import '../../data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';
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

  /// Ensures the Host has an active secret deck.
  /// If the host migrated or reconnected mid-round, this mathematically reconstructs
  /// the remaining undealt cards from all visible cards (board + hands + harvest)
  /// and preserves the bottom cut card if known.
  void _ensureSecretDeck(MatchState s) {
    if (s.deckCount > 0 && (_secretDeck == null || _secretDeck!.cards.isEmpty)) {
      _secretDeck = Deck.reconstructRemaining(
        s.board,
        s.handCards,
        s.harvestStacks,
        bottomCard: s.cutLastCard,
      );
      if (kDebugMode) {
        debugPrint('HOST MIGRATION / RECOVERY: Reconstructed secret deck with ${_secretDeck!.cards.length} cards (expected: ${s.deckCount})');
      }
    }
  }
  
  // Track last bound match for refresh recovery
  String? lastBoundMatchId;
  
  // Prevents multiple concurrent bot logic evaluations for the same state change
  bool _isHandlingBotLogic = false;
  // Timers for heartbeat and AFK monitoring
  Timer? _heartbeatTimer;
  Timer? _afkWatchdogTimer;
  StreamSubscription<CountdownTimer>? _autoplaySubscription;
  final Map<String, StreamSubscription<CountdownTimer>> _tafweetSubscriptions = {};
  
  // Stream subscription for the match listener
  StreamSubscription? _matchListener;
  StreamSubscription? _presenceListener;

  static const String _matchIdKey = 'last_match_id';

  Future<void> _publishState(MatchState newState) async {
    state = newState;
    if (!newState.id.startsWith('OFFLINE_')) {
      await ref.read(multiplayerSyncServiceProvider).updateMatchState(newState);
    } else {
      if (_amIHost(newState)) {
        _ensureSecretDeck(newState);
      }
      _evaluateBotActions(newState);
      _manageAutoplayTimer(newState);
    }
  }

  void _startHeartbeat() {
    if (lastBoundMatchId != null && lastBoundMatchId!.startsWith('OFFLINE_')) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (lastBoundMatchId != null) {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
           ref.read(multiplayerSyncServiceProvider).heartbeat(lastBoundMatchId!, currentUser.uid);
        }
      }
    });
  }

  void _manageAFKWatchdog(MatchState serverState) {
    if (!_amIHost(serverState)) {
      _afkWatchdogTimer?.cancel();
      _afkWatchdogTimer = null;
      return;
    }

    if (_afkWatchdogTimer == null || !_afkWatchdogTimer!.isActive) {
      _afkWatchdogTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        final currentState = state;
        if (currentState != null) {
          _checkAndHandleAFK(currentState);
          _evaluateBotActions(currentState);
        }
      });
    }
  }

  void _checkAndHandleAFK(MatchState serverState) {
    final now = DateTime.now();
    bool changed = false;
    final newOnlineStatus = Map<String, bool>.from(serverState.playerOnlineStatus);
    
    for (var playerId in serverState.playerIds) {
      if (playerId.startsWith('bot_')) continue;
      
      final lastActive = serverState.playerLastActive[playerId];
      if (lastActive != null) {
        final diff = now.difference(lastActive).inSeconds;
        // 15s threshold for "Offline" (AFK)
        final isOnline = diff < 15;
        if (newOnlineStatus[playerId] != isOnline) {
          newOnlineStatus[playerId] = isOnline;
          changed = true;
        if (kDebugMode) debugPrint('PRESENCE: Player $playerId is now ${isOnline ? 'Online' : 'Offline (AFK)'}');
        }
      }
    }

    if (changed) {
      _publishState(serverState.copyWith(playerOnlineStatus: newOnlineStatus));
    }
  }

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
      if (kDebugMode) debugPrint('RECOVERY: Attempting to recover match $lastId');
       bindToMatch(lastId);
    }
  }

  void leaveMatch() {
    if (lastBoundMatchId != null && !lastBoundMatchId!.startsWith('OFFLINE_')) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        // Apply forfeit penalty if leaving during active play
        final s = state;
        if (s != null && 
            s.phase != GamePhase.waitingForPlayers && 
            s.phase != GamePhase.matchOver &&
            s.phase != GamePhase.rematchVoting) {
          _applyForfeitPenalty(currentUser.uid);
        }
        
        ref.read(multiplayerSyncServiceProvider).removePresence(lastBoundMatchId!, currentUser.uid);
      }
    }
    _matchListener?.cancel();
    _presenceListener?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _afkWatchdogTimer?.cancel();
    _afkWatchdogTimer = null;
    _autoplaySubscription?.cancel();
    _autoplaySubscription = null;
    for (var sub in _tafweetSubscriptions.values) {
      sub.cancel();
    }
    _tafweetSubscriptions.clear();
    state = null;
    _clearMatchId();
  }

  bool _amIHost(MatchState s, {Map<String, bool>? presenceMap}) {
    if (s.id.startsWith('OFFLINE_')) return true;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;
    
    // HUMAN PRIORITY HOST ELECTION:
    // The Host is the first ONLINE human player in the playerIds list.
    for (var id in s.playerIds) {
      if (id.startsWith('bot_')) continue;
      
      final isOnline = (presenceMap != null) 
          ? (presenceMap[id] == true) 
          : (s.playerOnlineStatus[id] ?? false);
          
      if (isOnline) {
        return id == currentUser.uid;
      }
    }
    return false;
  }

  void bindToMatch(String matchId) {
    lastBoundMatchId = matchId;
    _saveMatchId(matchId);
    _matchListener?.cancel(); 
    
    if (matchId.startsWith('OFFLINE_')) {
      final s = state;
      if (s != null) {
        _ensureSecretDeck(s);
        _evaluateBotActions(s);
        _manageAutoplayTimer(s);
      }
      return;
    }

    _startHeartbeat();

    _matchListener = ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen(
      (serverState) {
        if (serverState != null) {
          try {
            state = serverState;
            if (_amIHost(serverState)) {
              _ensureSecretDeck(serverState);
            }
            _manageAFKWatchdog(serverState);
            _evaluateBotActions(serverState);
            _manageAutoplayTimer(serverState);
            
            // Sync local profile if needed (first join or update)
            _syncProfileWithMatch(serverState);
          } catch (e) {
            if (kDebugMode) debugPrint('ERROR in match listener callback: $e');
          }
        } else if (lastBoundMatchId != null) {
          leaveMatch();
        }
      },
      onError: (error) {
        debugPrint('MATCH LISTENER STREAM ERROR: $error');
      },
      cancelOnError: false,
    );

    // Initial Sync
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(multiplayerSyncServiceProvider).syncPresence(matchId, currentUser.uid);
    }
    
    // Listen for Store/Auth changes to sync profile real-time
    ref.listen(storeProvider, (prev, next) {
      final s = state;
      if (s != null) _syncProfileWithMatch(s);
    });
    ref.listen(currentUserProvider, (prev, next) {
      final s = state;
      if (s != null) _syncProfileWithMatch(s);
    });

    // Host Presence Watcher
    _presenceListener?.cancel();
    _presenceListener = ref.read(multiplayerSyncServiceProvider).watchPresence(matchId).listen((presence) {
       final serverState = state;
       if (serverState == null) return;
       
       // Host Transition: We use the ACTUAL presence map from RTDB during this transition to avoid circular locks.
       // If I am the first human online according to the presence map, I take over the state-update duties.
       final imPotentialHost = _amIHost(serverState, presenceMap: presence);
       if (!imPotentialHost) return;

       _ensureSecretDeck(serverState);

       final newOnlineStatus = Map<String, bool>.from(serverState.playerOnlineStatus);
       final newPlayerNames = Map<String, String>.from(serverState.playerNames);
       bool changed = false;

       for (var playerId in serverState.playerIds) {
         // Fix bot names on the fly if they were accidentally saved as 'Player'
         if (playerId.startsWith('bot_') && newPlayerNames[playerId] == 'player_default_name') {
           newPlayerNames[playerId] = 'bot_name_template';
           changed = true;
         }

         final isOnline = presence[playerId] == true;
         // Special case: if prefix is bot_, always online
         final actualOnline = playerId.startsWith('bot_') ? true : isOnline;
         if (newOnlineStatus[playerId] != actualOnline) {
           newOnlineStatus[playerId] = actualOnline;
           changed = true;
         }
       }

       // Hibernation / Auto-Destruct Logic
       DateTime? newExpireAt = serverState.expireAt;
       final anyoneOnline = newOnlineStatus.entries
           .where((e) => !e.key.startsWith('bot_'))
           .any((e) => e.value == true);

       if (!anyoneOnline && serverState.expireAt == null) {
         // Everyone left! Set 10-minute countdown
         newExpireAt = DateTime.now().add(const Duration(minutes: 10));
         changed = true;
       } else if (anyoneOnline && serverState.expireAt != null) {
         // Someone returned! Clear countdown
         newExpireAt = null;
         changed = true;
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
           playerNames: newPlayerNames,
           spectatorCount: currentSpectators,
           expireAt: newExpireAt,
         ));
       }
    });
  }

  void _syncProfileWithMatch(MatchState s) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    final store = ref.read(storeProvider);
    final myUid = user.uid;
    
    bool changed = false;
    final skins = Map<String, String>.from(s.playerSkins);
    final avatars = Map<String, String>.from(s.playerAvatars);
    final names = Map<String, String>.from(s.playerNames);

    if (skins[myUid] != store.activeCardBackId) {
      skins[myUid] = store.activeCardBackId;
      changed = true;
    }
    if (avatars[myUid] != user.avatarUrl) {
      avatars[myUid] = user.avatarUrl ?? "";
      changed = true;
    }
    if (names[myUid] != user.displayName) {
      names[myUid] = user.displayName;
      changed = true;
    }

    if (changed) {
      _publishState(s.copyWith(
        playerSkins: skins,
        playerAvatars: avatars,
        playerNames: names,
      ));
    }
  }

  void rebind(String matchId) {
    if (lastBoundMatchId == matchId && state != null) return;
    bindToMatch(matchId);
  }

  Future<void> _evaluateBotActions(MatchState serverState) async {
    if (_isHandlingBotLogic) return;
    _isHandlingBotLogic = true;

    if (!_amIHost(serverState)) {
      _isHandlingBotLogic = false;
      return;
    }
    // Safety delay to allow state to settle
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final currentState = serverState;
      if (currentState.playerIds.isEmpty) return;

      // 1. LOBBY AUTO-START
      if (currentState.phase == GamePhase.waitingForPlayers) {
        final humanCount = currentState.playerIds.where((id) => !id.startsWith('waiting_')).length;
        if (humanCount == 4) {
          await Future.delayed(const Duration(milliseconds: 1000));
          if (state?.phase == GamePhase.waitingForPlayers) {
            startNewRound(isFirstRound: true);
          }
        }
        return;
      }

      // 2. PHASE-BASED LOGIC (Host as Authority)
      switch (currentState.phase) {
        case GamePhase.preRoundCut:
          if (currentState.playerIds.isEmpty) break;
          int cutterIdx = (currentState.dealerIndex + (currentState.playerIds.length - 1)) % currentState.playerIds.length;
          String cutterId = currentState.playerIds[cutterIdx];
          bool isBot = cutterId.startsWith('bot_');
          bool isAFK = currentState.playerOnlineStatus[cutterId] == false;

          if (isBot || isAFK) {
            await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1000)));
            if (state?.phase == GamePhase.preRoundCut) {
              performCut(BotBrain.decideCut(currentState.deckCount));
            }
          }
          break;

        case GamePhase.dealingFasha:
          await dealInitialCards();
          break;

        case GamePhase.playing:
          // Check for subsequent deal or round completion (Host authoritative)
          bool allHandsEmpty = currentState.handCards.values.every((h) => h.isEmpty);
          if (allHandsEmpty) {
            if (currentState.deckCount > 0) {
              await Future.delayed(const Duration(milliseconds: 1000));
              if (state?.phase == GamePhase.playing && state?.deckCount == currentState.deckCount) {
                await dealSubsequentCards();
              }
            } else {
              await Future.delayed(const Duration(milliseconds: 1000));
              if (state?.phase == GamePhase.playing && state?.deckCount == 0) {
                await _handleRoundEnd();
              }
            }
            return;
          }

          // Bot/AFK/Stuck Turn Takeover
          final activeId = currentState.playerIds[currentState.currentTurnIndex];
          bool isBot = activeId.startsWith('bot_');
          bool isAFK = currentState.playerOnlineStatus[activeId] == false;

          // Watchdog: If player's turn exceeded timerDurationSeconds + 2s grace period,
          // it means their local client crashed, disconnected, or froze without autoplaying.
          bool isTurnStuck = false;
          if (currentState.turnStartTime != null) {
            final elapsed = DateTime.now().difference(currentState.turnStartTime!).inSeconds;
            if (elapsed >= (currentState.timerDurationSeconds + 2)) {
              isTurnStuck = true;
            }
          }

          if (isBot || isAFK || isTurnStuck) {
             if (kDebugMode) {
               if (isTurnStuck) {
                 debugPrint('TURN WATCHDOG: Host resolving stuck turn for $activeId');
               } else if (isAFK) {
                 debugPrint('AFK TAKEOVER: Host playing for $activeId');
               }
             }
             
             final delayMs = (isBot && !isTurnStuck) ? (800 + Random().nextInt(1500)) : 200;
             await Future.delayed(Duration(milliseconds: delayMs));
             final finalState = state;
             if (finalState != null && finalState.phase == GamePhase.playing && 
                 finalState.playerIds[finalState.currentTurnIndex] == activeId) {
                
                 try {
                   final decision = BotBrain.decidePlayAdvanced(finalState, activeId);
                   await playCard(activeId, decision.card);
                   if (decision.emojiReaction != null) {
                     sendEmoji(activeId, decision.emojiReaction!);
                   }
                 } catch (e) {
                   // Stuck failsafe: advance turn if BotBrain fails (e.g. no cards)
                   _publishState(finalState.copyWith(
                     currentTurnIndex: (finalState.currentTurnIndex + 1) % 4,
                     turnStartTime: DateTime.now(),
                   ));
                 }
             }
          }
          break;

        case GamePhase.shuffleVoting:
          _handleBotVotes(currentState, isRematch: false);
          break;
          
        case GamePhase.rematchVoting:
          _handleBotVotes(currentState, isRematch: true);
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('CRITICAL ASYNC ERROR in _evaluateBotActions: $e');
    } finally {
      _isHandlingBotLogic = false;
    }
  }

  Future<void> _handleBotVotes(MatchState currentState, {required bool isRematch}) async {
    for (var playerId in currentState.playerIds) {
      if (!playerId.startsWith('bot_')) continue;
      
      final votes = isRematch ? currentState.rematchVotes : currentState.shuffleVotes;
      if (!votes.containsKey(playerId)) {
        await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1500)));
        if (isRematch) {
          voteRematch(playerId, BotBrain.decideRematchVote());
        } else {
          voteShuffle(playerId, BotBrain.decideShuffleVote(currentState, playerId));
        }
      }
    }

    // Host Transition after voting
    final latestState = state;
    if (latestState == null) return;

    if (isRematch) {
      if (latestState.rematchVotes.length == 4) {
        _checkVoteCompletion(latestState);
      }
    } else {
      final sVotes = latestState.shuffleVotes;
      bool anyoneVotedNo = sVotes.values.any((v) => v == false);
      if (anyoneVotedNo || sVotes.length == 4) {
        startNewRound(forceShuffle: !anyoneVotedNo && sVotes.values.any((v) => v == true));
      }
    }
  }

  void _checkVoteCompletion(MatchState currentState) {
    if (currentState.phase == GamePhase.shuffleVoting) {
       final sVotes = currentState.shuffleVotes;
       bool anyoneVotedNo = sVotes.values.any((v) => v == false);
       if (anyoneVotedNo || sVotes.length == 4) {
         startNewRound(forceShuffle: !anyoneVotedNo && sVotes.values.any((v) => v == true));
       }
    } else if (currentState.phase == GamePhase.rematchVoting) {
       final rVotes = currentState.rematchVotes;
       final bool anyoneVotedNo = rVotes.values.any((v) => v == false);
       if (anyoneVotedNo) {
         _publishState(currentState.copyWith(phase: GamePhase.matchOver));
       } else if (rVotes.length == 4) {
         bool unanimous = rVotes.values.every((v) => v == true);
         if (unanimous) {
           _publishState(currentState.copyWith(
             teamAScore: 0, teamBScore: 0, roundCount: 1, roundsSinceLastShuffle: 0, rematchVotes: {},
           ));
           startNewRound(isFirstRound: true);
         } else {
           _publishState(currentState.copyWith(phase: GamePhase.matchOver));
         }
       }
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
    final store = ref.read(storeProvider);
    final avatarUrl = ref.read(currentUserProvider)?.avatarUrl ?? "";
    final initial = MatchState(
      id: newId,
      mode: mode,
      maxPoints: maxPoints,
      isPublic: isPublic,
      playerIds: [playerId, "waiting_1", "waiting_2", "waiting_3"],
      playerNames: {playerId: displayName},
      playerSkins: {playerId: store.activeCardBackId},
      playerAvatars: {playerId: avatarUrl},
      dealerIndex: 0,
      currentTurnIndex: 1, 
      phase: GamePhase.waitingForPlayers,
      timerDurationSeconds: timerDurationSeconds,
    );
    ref.read(multiplayerSyncServiceProvider).createMatch(initial);
    state = initial;
    bindToMatch(newId);
  }

  void startOfflinePracticeMatch(String playerId, String displayName, {GameMode mode = GameMode.classic, int maxPoints = 41}) {
    final offlineId = 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';
    final store = ref.read(storeProvider);
    final avatarUrl = ref.read(currentUserProvider)?.avatarUrl ?? "";

    final initial = MatchState(
      id: offlineId,
      mode: mode,
      maxPoints: maxPoints,
      isPublic: false,
      playerIds: [playerId, "bot_1", "bot_2", "bot_3"],
      playerNames: {
        playerId: displayName.isEmpty ? "Player" : displayName,
        "bot_1": "bot_name_template",
        "bot_2": "bot_name_template",
        "bot_3": "bot_name_template",
      },
      playerSkins: {
        playerId: store.activeCardBackId,
        "bot_1": "classic_blue",
        "bot_2": "classic_red",
        "bot_3": "classic_gold",
      },
      playerAvatars: {
        playerId: avatarUrl,
        "bot_1": "",
        "bot_2": "",
        "bot_3": "",
      },
      playerOnlineStatus: {
        playerId: true,
        "bot_1": true,
        "bot_2": true,
        "bot_3": true,
      },
      dealerIndex: 0,
      currentTurnIndex: 1, 
      phase: GamePhase.waitingForPlayers,
      timerDurationSeconds: 12,
    );

    state = initial;
    bindToMatch(offlineId);
    
    // Automatically transition to round 1 after 350ms
    Future.delayed(const Duration(milliseconds: 350), () {
      if (state?.id == offlineId) {
        startNewRound(isFirstRound: true);
      }
    });
  }

  Future<String> quickMatch(String playerId, String displayName, {GameMode mode = GameMode.classic}) async {
    final syncService = ref.read(multiplayerSyncServiceProvider);
    
    try {
      final snapshot = await syncService.roomsRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        final roomsMap = snapshot.value as Map;
        final now = DateTime.now();

        for (final entry in roomsMap.entries) {
          final roomId = entry.key.toString();
          if (entry.value is! Map) continue;
          final roomData = entry.value as Map;
          final summary = RoomSummary.fromJson(roomId, roomData);

          final bool isExpired = summary.expireAt != null && summary.expireAt!.isBefore(now);
          final bool hasOpenSeat = summary.playerIds.any((id) => id.startsWith('waiting_'));
          final bool isJoinable = summary.isPublic && 
                                  summary.phase == GamePhase.waitingForPlayers && 
                                  hasOpenSeat && 
                                  !isExpired;

          if (isJoinable && (summary.mode == mode || mode == GameMode.classic)) {
            await joinMatch(summary.id, playerId, displayName);
            return summary.id;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Quick match probe failed, falling back to create: $e');
    }

    // Auto-create public match if none found
    initializeMatch(
      playerId,
      displayName,
      mode,
      isPublic: true,
      maxPoints: 41,
      timerDurationSeconds: 10,
    );
    return state!.id;
  }

  void spectateMatch(String matchId) {
    bindToMatch(matchId);
  }

  Future<void> joinMatch(String matchId, String playerId, String displayName) async {
    final dbRef = FirebaseDatabase.instance.ref('matches/$matchId');
    final snapshot = await dbRef.get();
    if (!snapshot.exists) {
      throw Exception('room_not_found');
    }

    final json = Map<String, dynamic>.from(snapshot.value as Map);
    
    // AUTO-DESTRUCT check: If trying to join an expired room, delete it.
    if (json['expireAt'] != null) {
       final expireAt = DateTime.tryParse(json['expireAt'].toString());
       if (expireAt != null && DateTime.now().isAfter(expireAt)) {
         await ref.read(multiplayerSyncServiceProvider).deleteMatch(matchId);
         throw Exception('room_expired'); // Translation key
       }
    }

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
      
      final skins = Map<String, String>.from(json['playerSkins'] ?? {});
      skins[playerId] = ref.read(storeProvider).activeCardBackId;

      final avatars = Map<String, String>.from(json['playerAvatars'] ?? {});
      avatars[playerId] = ref.read(currentUserProvider)?.avatarUrl ?? "";

      await dbRef.update({
        'playerIds': playerIds,
        'playerNames': playerNames,
        'playerSkins': skins,
        'playerAvatars': avatars,
        'players/$playerId': true,
      });

      // Also update room index so lobby count updates
      final phaseStr = json['phase']?.toString() ?? 'waitingForPlayers';
      final isPublic = json['isPublic'] == true;
      final modeStr = json['mode']?.toString() ?? 'classic';
      final expireAtStr = json['expireAt']?.toString();
      
      await FirebaseDatabase.instance.ref('rooms/$matchId').update({
        'playerIds': playerIds,
        'mode': modeStr,
        'isPublic': isPublic,
        'phase': phaseStr,
        if (expireAtStr != null) 'expireAt': expireAtStr,
      });

      bindToMatch(matchId);
    } else {
      throw Exception('room_is_full');
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
      final newPlayerAvatars = Map<String, String>.from(currentState.playerAvatars);
      final newPlayerSkins = Map<String, String>.from(currentState.playerSkins);
      
      int botCount = 0;
      for (int i = 0; i < newPlayerIds.length; i++) {
        if (newPlayerIds[i].startsWith('waiting_')) {
          botCount++;
          final botId = 'bot_${i + 1}'; // Keep ID tied to index for stability
          newPlayerIds[i] = botId;
          newPlayerNames[botId] = 'Bot $botCount';
          newPlayerAvatars[botId] = ""; 
          newPlayerSkins[botId] = "classic_blue"; // Default bot skin
        }
      }
      
      await _publishState(currentState.copyWith(
        playerIds: newPlayerIds,
        playerNames: newPlayerNames,
        playerAvatars: newPlayerAvatars,
        playerSkins: newPlayerSkins,
        botInjectionVotes: votes,
      ));
    } else {
      await _publishState(currentState.copyWith(botInjectionVotes: votes));
    }
  }

  Future<void> startNewRound({bool isFirstRound = false, bool forceShuffle = false}) async {
    final currentState = state;
    if (currentState == null) return;
    
    // CRITICAL: Ensure we don't start with placeholders
    if (currentState.playerIds.any((id) => id.startsWith('waiting_'))) {
      debugPrint('ABORT: Attempted to start round with placeholders');
      return;
    }

    int nextDealer = isFirstRound ? 0 : (currentState.dealerIndex + 1) % 4;
    
    // Shuffle check
    bool shouldShuffle = isFirstRound || forceShuffle;
    if (shouldShuffle) {
      _secretDeck = Deck.standard();
      _secretDeck?.shuffle();
      ref.read(multimediaServiceProvider).playSfx('sfx/shuffle.mp3');
    } else {
      // RESTORE LOGIC: Pick up cards from last round
      _secretDeck = Deck.restoreFromHarvest(currentState.harvestStacks);
    }

    final newState = currentState.copyWith(
      dealerIndex: nextDealer,
      currentTurnIndex: (nextDealer + 1) % 4,
      phase: GamePhase.preRoundCut,
      roundCount: isFirstRound ? 1 : currentState.roundCount + 1,
      roundsSinceLastShuffle: shouldShuffle ? 0 : currentState.roundsSinceLastShuffle + 1,
      board: [],
      handCards: {},
      harvestStacks: {'teamA': [], 'teamB': []},
      shuffleVotes: {},
      rematchVotes: {},
      deckCount: _secretDeck?.cards.length ?? 0,
      lastCardRevealed: _secretDeck?.lastCardRevealed,
      recentFasha: [],
      lastCaptureTeam: null,
      cardOwnership: {},
    );

    await _publishState(newState);
  }

  Future<void> performCut(int index) async {
    final currentState = state;
    if (currentState == null) return;
    
    _ensureSecretDeck(currentState);

    final result = GameEngine.apply(
      currentState, 
      CutAction(currentState.playerIds[(currentState.dealerIndex + 3) % 4], index),
      secretDeck: _secretDeck
    );
    
    await _publishState(result.newState);
    _multimedia.playSfx('sfx/cut.mp3');
  }

  Future<void> dealInitialCards() async {
    final currentState = state;
    if (currentState == null || currentState.playerIds.isEmpty) return;

    _ensureSecretDeck(currentState);

    final dealerId = currentState.playerIds[currentState.dealerIndex % currentState.playerIds.length];
    final result = GameEngine.apply(
      currentState, 
      DealAction(dealerId, isInitial: true),
      secretDeck: _secretDeck
    );

    await _publishState(result.newState);
    _multimedia.playSfx('sfx/deal.mp3');

    // Memory phase delay (3s for snappy offline practice, 5s for multiplayer)
    final memoryDuration = currentState.id.startsWith('OFFLINE_') 
        ? const Duration(seconds: 3) 
        : const Duration(seconds: 5);
    await Future.delayed(memoryDuration);
    
    if (state?.phase == GamePhase.dealingCards) {
      await _publishState(state!.copyWith(
        phase: GamePhase.playing,
        turnStartTime: DateTime.now(),
      ));
    }
  }

  Future<void> dealSubsequentCards() async {
    final currentState = state;
    if (currentState == null || currentState.playerIds.isEmpty) return;

    _ensureSecretDeck(currentState);

    if (_secretDeck == null || _secretDeck!.cards.isEmpty) {
      if (currentState.deckCount == 0) {
        _handleRoundEnd();
      }
      return;
    }

    final dealerId = currentState.playerIds[currentState.dealerIndex % currentState.playerIds.length];
    final result = GameEngine.apply(
      currentState, 
      DealAction(dealerId, isInitial: false),
      secretDeck: _secretDeck
    );

    await _publishState(result.newState);
    _multimedia.playSfx('sfx/deal.mp3');
  }

  Future<void> sendEmoji(String playerId, String emoji) async {
    final currentState = state;
    if (currentState == null) return;
    final emojis = Map<String, String>.from(currentState.playerEmojis);
    emojis[playerId] = emoji;
    _multimedia.vibrate();
    await _publishState(currentState.copyWith(playerEmojis: emojis));
    
    Future.delayed(const Duration(seconds: 3), () => clearEmoji(playerId));
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
      MatchState? currentState = state;
      if (currentState == null || currentState.phase != GamePhase.playing) return;

      if (origin != null) {
        ref.read(localPlayOriginsProvider.notifier).update((m) => {...m, card.firebaseKey: origin});
      }

      final result = GameEngine.apply(currentState, PlayCardAction(playerId, card));
      final newState = result.newState;

      if (result.capturedCards.isNotEmpty) {
        final intermediateBoard = List<game_card.Card>.from(currentState.board)..add(card);
        final intermediateHands = Map<String, List<game_card.Card>>.from(currentState.handCards);
        intermediateHands[playerId]?.removeWhere((c) => c.firebaseKey == card.firebaseKey);
        
        await _publishState(currentState.copyWith(
          board: intermediateBoard,
          handCards: intermediateHands,
          phase: GamePhase.capturing,
          capturingCards: result.capturedCards,
          capturingTeam: result.capturingTeam,
          capturingStage: 0,
        ));

        _multimedia.playSfx('sfx/capture.mp3');
        await Future.delayed(const Duration(milliseconds: 600));

        await _publishState(state!.copyWith(capturingStage: 1));
        await Future.delayed(const Duration(milliseconds: 600));

        await _publishState(newState);
      } else {
        await _publishState(newState);
        _multimedia.playSfx('sfx/play.mp3');
      }

      bool allHandsEmpty = newState.handCards.values.every((h) => h.isEmpty);
      if (allHandsEmpty && _amIHost(newState)) {
        if (newState.deckCount > 0) {
          await dealSubsequentCards();
        } else {
          await _handleRoundEnd();
        }
      }
    } catch (e) {
      debugPrint('ERROR in playCard: $e');
    }
  }

  Future<void> _handleRoundEnd() async {
    try {
      final currentState = state;
      if (currentState == null) return;
       
      final harvest = Map<String, List<Capture>>.from(currentState.harvestStacks);
      final board = List<game_card.Card>.from(currentState.board);
      
      // 1. Last Capture Rule
      if (board.isNotEmpty && currentState.lastCaptureTeam != null) {
         harvest[currentState.lastCaptureTeam!]?.add(Capture(
           leadingCard: board.first, 
           capturedCards: board.skip(1).toList(),
         ));
      }

      // 2. Al-Ard logic (Counting total cards)
      int totalCardsA = harvest['teamA']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;
      int totalCardsB = harvest['teamB']?.fold(0, (prev, cap) => prev! + 1 + cap.capturedCards.length) ?? 0;

      int pointsA = currentState.teamAScore;
      int pointsB = currentState.teamBScore;

      if (totalCardsA > totalCardsB) {
         pointsA += ScoreConfig.majorityCapture;
      } else if (totalCardsB > totalCardsA) {
         pointsB += ScoreConfig.majorityCapture;
      }

      // 3. SHOW SCORING PHASE (Popping up the cards collected)
      final scoringState = currentState.copyWith(
         board: [],
         teamAScore: pointsA,
         teamBScore: pointsB,
         harvestStacks: harvest,
         phase: GamePhase.roundScoring,
      );
      
      await _publishState(scoringState);
      
      // Wait for users to see the result
      await Future.delayed(const Duration(seconds: 5));
      
      // Check if we are still in roundScoring (hasn't been interrupted)
      if (state?.phase != GamePhase.roundScoring) return;

      // 4. Check Match Win or Next Round
      if (pointsA >= scoringState.maxPoints || pointsB >= scoringState.maxPoints) {
          final winnerTeam = pointsA >= scoringState.maxPoints ? 'teamA' : 'teamB';
          _updateUserStatsAfterMatch(winnerTeam, pointsA, pointsB);

          await _publishState(scoringState.copyWith(
             phase: GamePhase.rematchVoting,
             skippedMatches: {},
             playHistory: [],
          ));
      } else {
         if (scoringState.roundsSinceLastShuffle >= 5) {
            await startNewRound(forceShuffle: true);
         } else if (scoringState.roundsSinceLastShuffle >= 2) {
            await _publishState(scoringState.copyWith(
               dealerIndex: (scoringState.dealerIndex + 1) % 4,
               phase: GamePhase.shuffleVoting,
               skippedMatches: {},
               playHistory: [],
            ));
         } else {
            await startNewRound(forceShuffle: false);
         }
      }
    } catch (e) {
      debugPrint('ERROR in _handleRoundEnd: $e');
    }
  }

  Future<void> voteShuffle(String playerId, bool wantsShuffle) async {
    final currentState = state;
    if (currentState == null) return;
    final result = GameEngine.apply(currentState, VoteAction(playerId, wantsShuffle, isRematch: false));
    await _publishState(result.newState);
    if (_amIHost(result.newState)) {
       _checkVoteCompletion(result.newState);
    }
  }

  Future<void> voteRematch(String playerId, bool wantsRematch) async {
    final currentState = state;
    if (currentState == null) return;
    final result = GameEngine.apply(currentState, VoteAction(playerId, wantsRematch, isRematch: true));
    await _publishState(result.newState);
    if (_amIHost(result.newState)) {
       _checkVoteCompletion(result.newState);
    }
  }


  Future<void> _updateUserStatsAfterMatch(String winnerTeam, int scoreA, int scoreB) async {
    final currentState = state;
    if (currentState == null) return;

    final isHost = _amIHost(currentState);
    if (!isHost) return;

    final Map<String, int> matchStars = {};
    final Map<String, int> matchCoins = {};

    for (int i = 0; i < currentState.playerIds.length; i++) {
      final playerId = currentState.playerIds[i];
      if (playerId.startsWith('bot_')) continue;

      final playerTeam = (i == 0 || i == 2) ? 'teamA' : 'teamB';
      final isWinner = playerTeam == winnerTeam;
      final myTeamScore = playerTeam == 'teamA' ? scoreA : scoreB;

      final int starsDelta = isWinner ? 50 : -30;
      final int coinsDelta = isWinner ? 100 : 20;

      matchStars[playerId] = starsDelta;
      matchCoins[playerId] = coinsDelta;

      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(playerId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final currentPoints = data['points'] ?? 0; // Points are now Stars
            final currentCoins = data['coins'] ?? 0;
            final currentWins = data['wins'] ?? 0;
            final currentLosses = data['losses'] ?? 0;
            final currentGames = data['gamesPlayed'] ?? 0;
            final currentBest = data['bestScore'] ?? 0;

            final newPoints = (currentPoints + starsDelta).clamp(0, 999999).toInt();

            transaction.update(userRef, {
              'points': newPoints,
              'coins': currentCoins + coinsDelta,
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

    // Update state one last time with rewards for everyone to see
    _publishState(currentState.copyWith(
      earnedStars: matchStars,
      earnedCoins: matchCoins,
    ));
  }

  Future<void> _applyForfeitPenalty(String playerId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(playerId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (snapshot.exists) {
          final currentPoints = snapshot.data()!['points'] ?? 0;
          transaction.update(userRef, {
            'points': (currentPoints - 50).clamp(0, 999999).toInt(),
          });
        }
      });
      debugPrint('FORFEIT: Deducted 50 stars from $playerId');
    } catch (e) {
      debugPrint('ERROR in forfeit penalty: $e');
    }
  }
}

final matchStateProvider = StateNotifierProvider<MatchStateNotifier, MatchState?>((ref) {
  // Watch multimedia service to ensure it's available for triggers
  ref.watch(multimediaServiceProvider); 
  return MatchStateNotifier(ref);
});
