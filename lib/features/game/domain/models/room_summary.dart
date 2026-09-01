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

  RoomSummary({
    required this.id,
    required this.mode,
    required this.playerIds,
    required this.isPublic,
    required this.phase,
    this.expireAt,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'playerIds': playerIds,
        'isPublic': isPublic,
        'phase': phase.name,
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
    );
  }
}
