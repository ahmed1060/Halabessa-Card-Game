import '../models/match_state.dart';

/// A request hint, not gameplay authority. One connected human requests first;
/// others stagger repair requests if no new accepted revision arrives. Server
/// clocks and version checks still decide whether any transition is legal.
class ServerProgressCoordinator {
  int? _version;
  String? _room;
  DateTime? _dueSince;
  DateTime? _lastRequest;

  bool shouldRequest({
    required MatchState state,
    required String uid,
    required DateTime now,
    required bool due,
    Map<String, bool>? presence,
  }) {
    if (!due) {
      _dueSince = null;
      _lastRequest = null;
      return false;
    }
    if (_room != state.id ||
        _version != state.serverVersion ||
        _dueSince == null) {
      _room = state.id;
      _version = state.serverVersion;
      _dueSince = now;
      _lastRequest = null;
    }
    final humans = state.playerIds
        .where(
          (id) =>
              !id.startsWith('bot_') &&
              !id.startsWith('waiting_') &&
              (id == uid || presence == null || presence[id] == true),
        )
        .toList();
    final rank = humans.indexOf(uid);
    if (rank < 0) return false;
    // Managed rooms normally advance without client commands. Repair only
    // after a missed deadline, stagger narrowly, and coalesce retries.
    final delay = state.serverProgressManaged ? 1500 + rank * 250 : rank * 1500;
    if (now.difference(_dueSince!).inMilliseconds < delay ||
        (_lastRequest != null && now.difference(_lastRequest!).inMilliseconds < 1000)) return false;
    _lastRequest = now;
    return true;
  }
}
