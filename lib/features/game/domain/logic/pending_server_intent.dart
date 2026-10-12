import 'dart:async';
import '../models/match_state.dart';

/// Only a receipt in an authoritative revision can release an uncertain intent.
class PendingServerIntent {
  final String roomId;
  final String commandId;
  final int expectedVersion;
  final _confirmation = Completer<bool>();
  bool confirmed = false;
  PendingServerIntent(this.roomId, this.commandId, this.expectedVersion);
  Future<bool> get confirmation => _confirmation.future;

  bool confirm(MatchState snapshot) {
    if (confirmed ||
        !snapshot.usesServerCommands ||
        snapshot.id != roomId ||
        snapshot.serverVersion <= expectedVersion ||
        !snapshot.recentCommandIds.contains(commandId))
      return false;
    confirmed = true;
    _confirmation.complete(true);
    return true;
  }
}
