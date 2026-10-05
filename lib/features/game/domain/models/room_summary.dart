import 'match_state.dart';

/// Lightweight mirror of a match, written to the separate `rooms/$matchId`
/// RTDB tree so the lobby can list joinable rooms without subscribing to
/// `matches` -- which downloads every match's full object (board, chat,
/// playHistory, presence, ...) to every client sitting on the home screen,
/// re-sent on every single write to any match, active games included. See
/// HAL-06. Carries only what PublicRoomsList actually renders or acts on.
class RoomSummary {
  final String id;
  final GameMode mode;
  final List<String> playerIds;
  final bool isPublic;
  final GamePhase phase;
  final DateTime? expireAt;
  final int protocolVersion;
  final int replacementSeatCount;
  final int safeReplacementSeatCount;

  int get openSeatCount => phase == GamePhase.waitingForPlayers
      ? playerIds.where((id) => id.startsWith('waiting_')).length : replacementSeatCount;
  bool get isActiveReplacementRoom => protocolVersion == 1 &&
      (phase == GamePhase.playing ||
        (playerIds.length == 4 && playerIds.every((id) => id.startsWith('bot_')) &&
          [GamePhase.preRoundCut, GamePhase.dealingFasha, GamePhase.dealingCards,
            GamePhase.capturing].contains(phase))) && replacementSeatCount > 0;
  bool isVisiblePublic(DateTime now) => isPublic &&
      (expireAt == null || expireAt!.isAfter(now)) &&
      (phase == GamePhase.waitingForPlayers || isActiveReplacementRoom);
  bool isJoinable(DateTime now) => isVisiblePublic(now) &&
      (phase == GamePhase.waitingForPlayers ? openSeatCount > 0 : safeReplacementSeatCount > 0);

  RoomSummary({
    required this.id,
    required this.mode,
    required this.playerIds,
    required this.isPublic,
    required this.phase,
    this.expireAt,
    this.protocolVersion = 0,
    this.replacementSeatCount = 0,
    this.safeReplacementSeatCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'playerIds': playerIds,
        'isPublic': isPublic,
        'phase': phase.name,
        'protocolVersion': protocolVersion,
        'replacementSeatCount': replacementSeatCount,
        'safeReplacementSeatCount': safeReplacementSeatCount,
        if (expireAt != null) 'expireAt': expireAt!.toIso8601String(),
      };

  factory RoomSummary.fromJson(String id, Map<dynamic, dynamic> json) {
    return RoomSummary(
      id: id,
      mode: GameMode.values.firstWhere(
        (e) => e.name == json['mode']?.toString(),
        orElse: () => GameMode.classic,
      ),
      playerIds: (json['playerIds'] is List) ? (json['playerIds'] as List).map((e) => e.toString()).toList() : <String>[],
      isPublic: json['isPublic'] == true,
      phase: GamePhase.values.firstWhere(
        (e) => e.name == json['phase']?.toString(),
        orElse: () => GamePhase.waitingForPlayers,
      ),
      expireAt: json['expireAt'] != null ? DateTime.tryParse(json['expireAt'].toString()) : null,
      protocolVersion: json['protocolVersion'] is num ? (json['protocolVersion'] as num).toInt() : 0,
      replacementSeatCount: json['replacementSeatCount'] is num
          ? (json['replacementSeatCount'] as num).toInt().clamp(0, 4) : 0,
      safeReplacementSeatCount: json['safeReplacementSeatCount'] is num
          ? (json['safeReplacementSeatCount'] as num).toInt().clamp(0, 4) : 0,
    );
  }
}
