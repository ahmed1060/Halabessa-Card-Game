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
import '../../domain/models/game_action.dart';
import '../../domain/logic/deck.dart';
import '../../domain/logic/game_engine.dart';
import '../../domain/logic/bot_brain.dart';
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
    await ref.read(multiplayerSyncServiceProvider).updateMatchState(newState);
  }

  void _startHeartbeat() {
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
          debugPrint('PRESENCE: Player $playerId is now ${isOnline ? 'Online' : 'Offline (AFK)'}');
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
       debugPrint('RECOVERY: Attempting to recover match $lastId');
       bindToMatch(lastId);
    }
  }

  void leaveMatch() {
    if (lastBoundMatchId != null) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
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
    
    _startHeartbeat();

    _matchListener = ref.read(multiplayerSyncServiceProvider).watchMatch(matchId).listen(
      (serverState) {
        if (serverState != null) {
          try {
            state = serverState;
            _manageAFKWatchdog(serverState);
            _evaluateBotActions(serverState);
            _manageAutoplayTimer(serverState);
          } catch (e, stack) {
            debugPrint('ERROR in match listener callback: $e');
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
       
       // Host Transition: We use the ACTUAL presence map from RTDB during this transition to avoid circular locks.
       // If I am the first human online according to the presence map, I take over the state-update duties.
       final imPotentialHost = _amIHost(serverState, presenceMap: presence);
       if (!imPotentialHost) return;

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
          int cutterIdx = (currentState.dealerIndex + 3) % 4;
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
          // Check for subsequent deal
          bool allHandsEmpty = currentState.handCards.values.every((h) => h.isEmpty);
          if (allHandsEmpty && currentState.deckCount > 0) {
            await Future.delayed(const Duration(milliseconds: 1000));
            if (state?.phase == GamePhase.playing && state?.deckCount == currentState.deckCount) {
              await dealSubsequentCards();
            }
            return;
          }

          // Bot/AFK Turn Takeover
          final activeId = currentState.playerIds[currentState.currentTurnIndex];
          bool isBot = activeId.startsWith('bot_');
          bool isAFK = currentState.playerOnlineStatus[activeId] == false;

          if (isBot || isAFK) {
             if (isAFK) debugPrint('AFK TAKEOVER: Host playing for $activeId');
             
             await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(1500)));
             final finalState = state;
             if (finalState != null && finalState.phase == GamePhase.playing && 
                 finalState.playerIds[finalState.currentTurnIndex] == activeId) {
                
                try {
                  final action = BotBrain.decidePlay(finalState, activeId);
                  playCard(activeId, action.card);
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
    } catch (e, stack) {
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
        if (latestState.rematchVotes.values.every((v) => v == true)) {
          // Rematch handled in voteRematch currently
        }
      }
    } else {
      final sVotes = latestState.shuffleVotes;
       bool anyoneVotedNo = sVotes.values.any((v) => v == false);
       if (anyoneVotedNo || sVotes.length == 4) {
         startNewRound(forceShuffle: !anyoneVotedNo && sVotes.values.any((v) => v == true));
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
      
      int botCount = 0;
      for (int i = 0; i < newPlayerIds.length; i++) {
        if (newPlayerIds[i].startsWith('waiting_')) {
          botCount++;
          final botId = 'bot_${i + 1}'; // Keep ID tied to index for stability
          newPlayerIds[i] = botId;
          newPlayerNames[botId] = 'Bot $botCount';
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
      recentFasha: [],
      lastCaptureTeam: null,
    );

    await _publishState(newState);
    _multimedia.playSfx('sfx/shuffle.mp3');
  }

  Future<void> performCut(int index) async {
    final currentState = state;
    if (currentState == null) return;
    
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
    if (currentState == null) return;

    final result = GameEngine.apply(
      currentState, 
      DealAction(currentState.playerIds[currentState.dealerIndex], isInitial: true),
      secretDeck: _secretDeck
    );

    await _publishState(result.newState);
    _multimedia.playSfx('sfx/deal.mp3');

    // Memory phase delay
    await Future.delayed(const Duration(seconds: 5));
    
    if (state?.phase == GamePhase.dealingCards) {
      await _publishState(state!.copyWith(
        phase: GamePhase.playing,
        turnStartTime: DateTime.now(),
      ));
    }
  }

  Future<void> dealSubsequentCards() async {
    final currentState = state;
    if (currentState == null || _secretDeck == null || _secretDeck!.cards.isEmpty) {
      if (currentState != null && currentState.deckCount == 0) {
        _handleRoundEnd();
      }
      return;
    }

    final result = GameEngine.apply(
      currentState, 
      DealAction(currentState.playerIds[currentState.dealerIndex], isInitial: false),
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
      final currentState = state;
      if (currentState == null || currentState.phase != GamePhase.playing) return;

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
      if (allHandsEmpty) {
        await dealSubsequentCards();
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
      
      // Last Capture Rule
      if (board.isNotEmpty && currentState.lastCaptureTeam != null) {
         harvest[currentState.lastCaptureTeam!]?.add(Capture(
           leadingCard: board.first, 
           capturedCards: board.skip(1).toList(),
         ));
      }

      // Al-Ard logic
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
      
     if (pointsA >= endPhase.maxPoints || pointsB >= endPhase.maxPoints) {
          final winnerTeam = pointsA >= endPhase.maxPoints ? 'teamA' : 'teamB';
          _updateUserStatsAfterMatch(winnerTeam, pointsA, pointsB);

          await _publishState(endPhase.copyWith(
             phase: GamePhase.rematchVoting,
             skippedMatches: {},
             playHistory: [],
          ));
      } else {
         if (endPhase.roundsSinceLastShuffle >= 5) {
            await startNewRound(forceShuffle: true);
         } else if (endPhase.roundsSinceLastShuffle >= 2) {
            await _publishState(endPhase.copyWith(
               dealerIndex: (endPhase.dealerIndex + 1) % 4,
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
  }

  Future<void> voteRematch(String playerId, bool wantsRematch) async {
    final currentState = state;
    if (currentState == null) return;
    final result = GameEngine.apply(currentState, VoteAction(playerId, wantsRematch, isRematch: true));
    
    if (result.newState.rematchVotes.length == 4) {
      bool unanimous = result.newState.rematchVotes.values.every((v) => v == true);
      if (unanimous) {
        await _publishState(result.newState.copyWith(
          teamAScore: 0, teamBScore: 0, roundCount: 1, roundsSinceLastShuffle: 0, rematchVotes: {},
        ));
        startNewRound(isFirstRound: true);
      } else {
        await _publishState(result.newState.copyWith(phase: GamePhase.matchOver));
      }
    } else {
      await _publishState(result.newState);
    }
  }


  Future<void> _updateUserStatsAfterMatch(String winnerTeam, int scoreA, int scoreB) async {
    final currentState = state;
    if (currentState == null) return;

    final isHost = _amIHost(currentState);
    
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
