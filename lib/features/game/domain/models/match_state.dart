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

  // Deck & Board State
  final List<game_card.Card> deck; // Remaining Deck
  final List<game_card.Card> board; // Cards present on the ground
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

  MatchState({
    required this.id,
    required this.mode,
    this.maxPoints = 41,
    required this.playerIds,
    this.deck = const [],
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
  });

  MatchState copyWith({
    String? id,
    GameMode? mode,
    int? maxPoints,
    List<String>? playerIds,
    List<game_card.Card>? deck,
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
  }) {
    return MatchState(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      maxPoints: maxPoints ?? this.maxPoints,
      playerIds: playerIds ?? this.playerIds,
      deck: deck ?? this.deck,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.name,
      'maxPoints': maxPoints,
      'playerIds': playerIds,
      'deck': deck.map((c) => c.toJson()).toList(),
      'board': board.map((c) => c.toJson()).toList(),
      'recentFasha': recentFasha.map((c) => c.toJson()).toList(),
      'handCards': handCards.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
      'harvestStacks': harvestStacks.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
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
    };
  }

  factory MatchState.fromJson(Map<dynamic, dynamic> json) {
    List<game_card.Card> parseCards(dynamic list) {
      if (list == null) return [];
      return (list as List).map((i) => game_card.Card.fromJson(Map<String, dynamic>.from(i as Map))).toList();
    }

    List<Capture> parseCaptures(dynamic list) {
      if (list == null) return [];
      return (list as List).map((i) => Capture.fromJson(Map<String, dynamic>.from(i as Map))).toList();
    }
    
    Map<String, List<game_card.Card>> parseCardMap(dynamic map) {
      if (map == null) return {};
      final result = <String, List<game_card.Card>>{};
      (map as Map).forEach((key, value) {
        result[key.toString()] = parseCards(value);
      });
      return result;
    }

    Map<String, List<Capture>> parseCaptureMap(dynamic map) {
      final result = <String, List<Capture>>{
        'teamA': [],
        'teamB': [],
      };
      if (map != null) {
        (map as Map).forEach((key, value) {
          result[key.toString()] = parseCaptures(value);
        });
      }
      return result;
    }

    return MatchState(
      id: json['id'] as String? ?? '',
      mode: GameMode.values.byName(json['mode'] as String? ?? 'classic'),
      maxPoints: json['maxPoints'] as int? ?? 41,
      playerIds: (json['playerIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      deck: parseCards(json['deck']),
      board: parseCards(json['board']),
      recentFasha: parseCards(json['recentFasha']),
      handCards: parseCardMap(json['handCards']),
      harvestStacks: parseCaptureMap(json['harvestStacks']),
      teamAScore: json['teamAScore'] as int? ?? 0,
      teamBScore: json['teamBScore'] as int? ?? 0,
      dealerIndex: json['dealerIndex'] as int? ?? 0,
      currentTurnIndex: json['currentTurnIndex'] as int? ?? 0,
      phase: GamePhase.values.byName(json['phase'] as String? ?? 'preRoundCut'),
      lastCaptureTeam: json['lastCaptureTeam'] as String?,
      roundCount: json['roundCount'] as int? ?? 1,
      roundsSinceLastShuffle: json['roundsSinceLastShuffle'] as int? ?? 0,
      consecutiveTafweetCount: json['consecutiveTafweetCount'] as int? ?? 0,
      turnStartTime: json['turnStartTime'] != null ? DateTime.parse(json['turnStartTime'] as String) : null,
      timerDurationSeconds: json['timerDurationSeconds'] as int? ?? 10,
      playerEmojis: (json['playerEmojis'] as Map?)?.cast<String, String>() ?? const {},
      shuffleVotes: (json['shuffleVotes'] as Map?)?.cast<String, bool>() ?? const {},
      rematchVotes: (json['rematchVotes'] as Map?)?.cast<String, bool>() ?? const {},
      botInjectionVotes: (json['botInjectionVotes'] as Map?)?.cast<String, bool>() ?? const {},
    );
  }
}
