import 'package:flutter/foundation.dart';
import 'card.dart' as game_card;
import 'capture.dart';

enum GamePhase { waitingForPlayers, preRoundCut, dealingFasha, dealingCards, playing, roundScoring, shuffleVoting, rematchVoting, matchOver }
enum GameMode { classic, tafweet }

class MatchState {
  final String id;
  final GameMode mode;
  final int maxPoints; // 21, 41, 61
  
  // Players Array: [T1_P1, T2_P1, T1_P2, T2_P2] -> [0, 1, 2, 3]
  // Teams: A is indices [0, 2], B is indices [1, 3]
  final List<String> playerIds;
  final Map<String, String> playerNames; // Synced ID -> DisplayName
  final bool isPublic;
  final Map<String, String> cardOwnership; // cardId -> playerWhoPlayedIt

  // Deck & Board State
  // Removed shared deck list for security (Anti-Cheat)
  final List<game_card.Card> board; 
  final List<game_card.Card> recentFasha; // Temporarily holds the layout of Fasha for 5s preview

  // Player Hands: Map<PlayerId, List<game_card.Card>>
  final Map<String, List<game_card.Card>> handCards;
  
  // Harvested cards per team grouped by capture event
  final Map<String, List<Capture>> harvestStacks;
  
  // Points tracked match-level
  final int teamAScore;
  final int teamBScore;

  // Turn management
  final int dealerIndex; // Rotates every round
  final int currentTurnIndex; // Active player
  final GamePhase phase;
  final String? lastCaptureTeam; // Used for "Last Capture Rule" at the end of the round
  
  // Round Counter & Memory Shuffle tracker
  final int roundCount;
  final int roundsSinceLastShuffle;
  final int consecutiveTafweetCount;

  // Turn Timers & Reactions
  final DateTime? turnStartTime;
  final int timerDurationSeconds;
  final Map<String, String> playerEmojis;
  final Map<String, bool> shuffleVotes;
  final Map<String, bool> rematchVotes;
  final Map<String, bool> botInjectionVotes;
  final int deckCount;
  final Map<String, List<String>> skippedMatches;
  final List<game_card.Card> playHistory;

  MatchState({
    required this.id,
    required this.mode,
    this.maxPoints = 41,
    required this.playerIds,
    this.board = const [],
    this.recentFasha = const [],
    this.handCards = const {},
    this.harvestStacks = const {'teamA': [], 'teamB': []},
    this.teamAScore = 0,
    this.teamBScore = 0,
    required this.dealerIndex,
    required this.currentTurnIndex,
    this.phase = GamePhase.preRoundCut,
    this.lastCaptureTeam,
    this.roundCount = 1,
    this.roundsSinceLastShuffle = 0,
    this.consecutiveTafweetCount = 0,
    this.turnStartTime,
    this.timerDurationSeconds = 10,
    this.playerEmojis = const {},
    this.shuffleVotes = const {},
    this.rematchVotes = const {},
    this.botInjectionVotes = const {},
    this.playerNames = const {},
    this.isPublic = false,
    this.cardOwnership = const {},
    this.deckCount = 0,
    this.skippedMatches = const {},
    this.playHistory = const [],
  });

  MatchState copyWith({
    String? id,
    GameMode? mode,
    int? maxPoints,
    List<String>? playerIds,
    List<game_card.Card>? board,
    List<game_card.Card>? recentFasha,
    Map<String, List<game_card.Card>>? handCards,
    Map<String, List<Capture>>? harvestStacks,
    int? teamAScore,
    int? teamBScore,
    int? dealerIndex,
    int? currentTurnIndex,
    GamePhase? phase,
    String? lastCaptureTeam,
    int? roundCount,
    int? roundsSinceLastShuffle,
    int? consecutiveTafweetCount,
    DateTime? turnStartTime,
    int? timerDurationSeconds,
    Map<String, String>? playerEmojis,
    Map<String, bool>? shuffleVotes,
    Map<String, bool>? rematchVotes,
    Map<String, bool>? botInjectionVotes,
    Map<String, String>? playerNames,
    bool? isPublic,
    Map<String, String>? cardOwnership,
    int? deckCount,
    Map<String, List<String>>? skippedMatches,
    List<game_card.Card>? playHistory,
  }) {
    return MatchState(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      maxPoints: maxPoints ?? this.maxPoints,
      playerIds: playerIds ?? this.playerIds,
      board: board ?? this.board,
      recentFasha: recentFasha ?? this.recentFasha,
      handCards: handCards ?? this.handCards,
      harvestStacks: harvestStacks ?? this.harvestStacks,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      phase: phase ?? this.phase,
      lastCaptureTeam: lastCaptureTeam ?? this.lastCaptureTeam,
      roundCount: roundCount ?? this.roundCount,
      roundsSinceLastShuffle: roundsSinceLastShuffle ?? this.roundsSinceLastShuffle,
      consecutiveTafweetCount: consecutiveTafweetCount ?? this.consecutiveTafweetCount,
      turnStartTime: turnStartTime ?? this.turnStartTime,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
      playerEmojis: playerEmojis ?? this.playerEmojis,
      shuffleVotes: shuffleVotes ?? this.shuffleVotes,
      rematchVotes: rematchVotes ?? this.rematchVotes,
      botInjectionVotes: botInjectionVotes ?? this.botInjectionVotes,
      playerNames: playerNames ?? this.playerNames,
      isPublic: isPublic ?? this.isPublic,
      cardOwnership: cardOwnership ?? this.cardOwnership,
      deckCount: deckCount ?? this.deckCount,
      skippedMatches: skippedMatches ?? this.skippedMatches,
      playHistory: playHistory ?? this.playHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.name,
      'maxPoints': maxPoints,
      'playerIds': playerIds,
      'deckCount': deckCount,
      'board': board.map((c) => c.toJson()).toList(),
      'recentFasha': recentFasha.map((c) => c.toJson()).toList(),
      'handCards': handCards.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
      'harvestStacks': harvestStacks.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
      'skippedMatches': skippedMatches,
      'playHistory': playHistory.map((c) => c.toJson()).toList(),
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'dealerIndex': dealerIndex,
      'currentTurnIndex': currentTurnIndex,
      'phase': phase.name,
      'lastCaptureTeam': lastCaptureTeam,
      'roundCount': roundCount,
      'roundsSinceLastShuffle': roundsSinceLastShuffle,
      'consecutiveTafweetCount': consecutiveTafweetCount,
      'turnStartTime': turnStartTime == null ? null : turnStartTime!.toIso8601String(),
      'timerDurationSeconds': timerDurationSeconds,
      'playerEmojis': playerEmojis,
      'shuffleVotes': shuffleVotes,
      'rematchVotes': rematchVotes,
      'botInjectionVotes': botInjectionVotes,
      'playerNames': playerNames,
      'isPublic': isPublic,
      'cardOwnership': cardOwnership,
    };
  }

  factory MatchState.fromJson(Map<dynamic, dynamic> json) {
    // Helper for robust String -> String map parsing (Firebase minification safety)
    Map<String, String> parseStringMap(dynamic map) {
      if (map == null || map is! Map) return {};
      return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }

    // Helper for robust String -> Bool map parsing
    Map<String, bool> parseBoolMap(dynamic map) {
      if (map == null || map is! Map) return {};
      return map.map((k, v) => MapEntry(k.toString(), v == true));
    }

    List<game_card.Card> parseCards(dynamic list) {
      if (list == null) return [];
      if (list is Map) {
        try {
          final sortedKeys = list.keys.map((e) => int.tryParse(e.toString())).whereType<int>().toList()..sort();
          return sortedKeys.map((k) {
            final item = list[k.toString()];
            if (item is Map) {
              return game_card.Card.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          }).whereType<game_card.Card>().toList();
        } catch (e) {
          return [];
        }
      }
      if (list is List) {
        return list.map((i) {
          if (i is Map) {
            return game_card.Card.fromJson(Map<String, dynamic>.from(i));
          }
          return null;
        }).whereType<game_card.Card>().toList();
      }
      return [];
    }

    List<Capture> parseCaptures(dynamic list) {
      if (list == null) return [];
      if (list is Map) {
        try {
          final sortedKeys = list.keys.map((e) => int.tryParse(e.toString())).whereType<int>().toList()..sort();
          return sortedKeys.map((k) {
            final item = list[k.toString()];
            if (item is Map) {
              return Capture.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          }).whereType<Capture>().toList();
        } catch (e) {
          return [];
        }
      }
      if (list is List) {
        return list.map((i) {
          if (i is Map) {
            return Capture.fromJson(Map<String, dynamic>.from(i));
          }
          return null;
        }).whereType<Capture>().toList();
      }
      return [];
    }

    Map<String, List<String>> parseSkipMap(dynamic map) {
      if (map == null || map is! Map) return {};
      final result = <String, List<String>>{};
      map.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((e) => e.toString()).toList();
        } else if (value is Map) {
          // Backward compatibility if it was still Card objects
          result[key.toString()] = [];
        }
      });
      return result;
    }

    Map<String, List<game_card.Card>> parseCardMap(dynamic map) {
      if (map == null || map is! Map) return {};
      final result = <String, List<game_card.Card>>{};
      map.forEach((key, value) {
        result[key.toString()] = parseCards(value);
      });
      return result;
    }

    Map<String, List<Capture>> parseCaptureMap(dynamic map) {
      final result = <String, List<Capture>>{
        'teamA': [],
        'teamB': [],
      };
      if (map == null) return result;

      if (map is Map) {
        map.forEach((key, value) {
          final kStr = key.toString();
          if (kStr == 'teamA' || kStr == 'teamB') {
            result[kStr] = parseCaptures(value);
          }
        });
      }
      return result;
    }

    try {
      final id = json['id']?.toString() ?? '';
      
      final GameMode mode = GameMode.values.firstWhere(
        (e) => e.name == json['mode']?.toString(), 
        orElse: () => GameMode.classic
      );
      
      final maxPoints = json['maxPoints'] is int ? json['maxPoints'] as int : 41;
      
      final playerIds = (json['playerIds'] is List) 
          ? (json['playerIds'] as List).map((e) => e.toString()).toList() 
          : <String>[];
      
      // Use ultra-safe map parsing helpers
      final playerEmojis = parseStringMap(json['playerEmojis']);
      final shuffleVotes = parseBoolMap(json['shuffleVotes']);
      final rematchVotes = parseBoolMap(json['rematchVotes']);
      final botInjectionVotes = parseBoolMap(json['botInjectionVotes']);
      final playerNames = parseStringMap(json['playerNames']);
      final cardOwnership = parseStringMap(json['cardOwnership']);

      return MatchState(
        id: id,
        mode: mode,
        maxPoints: maxPoints,
        playerIds: playerIds,
        board: parseCards(json['board']),
        recentFasha: parseCards(json['recentFasha']),
        handCards: parseCardMap(json['handCards']),
        harvestStacks: parseCaptureMap(json['harvestStacks']),
        teamAScore: json['teamAScore'] is int ? json['teamAScore'] as int : 0,
        teamBScore: json['teamBScore'] is int ? json['teamBScore'] as int : 0,
        dealerIndex: json['dealerIndex'] is int ? json['dealerIndex'] as int : 0,
        currentTurnIndex: json['currentTurnIndex'] is int ? json['currentTurnIndex'] as int : 0,
        phase: GamePhase.values.firstWhere(
          (e) => e.name == json['phase']?.toString(), 
          orElse: () => GamePhase.waitingForPlayers
        ),
        lastCaptureTeam: json['lastCaptureTeam']?.toString(),
        roundCount: json['roundCount'] is int ? json['roundCount'] as int : 1,
        roundsSinceLastShuffle: json['roundsSinceLastShuffle'] is int ? json['roundsSinceLastShuffle'] as int : 0,
        consecutiveTafweetCount: json['consecutiveTafweetCount'] is int ? json['consecutiveTafweetCount'] as int : 0,
        turnStartTime: json['turnStartTime'] != null ? DateTime.tryParse(json['turnStartTime'].toString()) : null,
        timerDurationSeconds: json['timerDurationSeconds'] is int ? json['timerDurationSeconds'] as int : 10,
        playerEmojis: playerEmojis,
        shuffleVotes: shuffleVotes,
        rematchVotes: rematchVotes,
        botInjectionVotes: botInjectionVotes,
        playerNames: playerNames,
        isPublic: json['isPublic'] == true,
        cardOwnership: cardOwnership,
        deckCount: json['deckCount'] is int ? json['deckCount'] as int : 0,
        skippedMatches: parseSkipMap(json['skippedMatches']),
        playHistory: parseCards(json['playHistory']),
      );
    } catch (e, stack) {
      debugPrint('RECOVERED MatchState.fromJson failure: $e');
      debugPrint('Stack: $stack');
      // Return a dummy state instead of crashing the whole app
      return MatchState(
        id: 'error_recovery',
        mode: GameMode.classic,
        playerIds: [],
        dealerIndex: 0,
        currentTurnIndex: 0,
        phase: GamePhase.waitingForPlayers,
      );
    }
  }
}
