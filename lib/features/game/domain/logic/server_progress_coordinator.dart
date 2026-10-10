import '../models/match_state.dart';

/// A request hint, not gameplay authority. One connected human requests first;
/// others stagger repair requests if no new accepted revision arrives. Server
/// clocks and version checks still decide whether any transition is legal.
class ServerProgressCoordinator {
  int? _version;
  String? _room;
  DateTime? _dueSince;

  bool shouldRequest({
    required MatchState state,
    required String uid,
    required DateTime now,
    required bool due,
    Map<String, bool>? presence,
  }) {
    if (!due) {
      _dueSince = null;
      return false;
    }
    if (_room != state.id ||
        _version != state.serverVersion ||
        _dueSince == null) {
      _room = state.id;
      _version = state.serverVersion;
      _dueSince = now;
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
    return now.difference(_dueSince!).inMilliseconds >= rank * 1500;
  }
}
