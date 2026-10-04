import 'dart:async';

import '../../domain/models/match_state.dart';

/// RTDB is a revision notification channel, not the source of private hands.
/// Fetching both parts together prevents rendering a new board with old cards.
Stream<MatchState?> watchCommandSnapshots({
  required Stream<Map<String, dynamic>?> notifications,
  required Future<MatchState> Function() fetchSnapshot,
  required String roomId,
  String? callerUid,
}) {
  late StreamController<MatchState?> controller;
  StreamSubscription<Map<String, dynamic>?>? subscription;
  var generation = 0;
  var wantedVersion = -1;
  var deliveredVersion = -1;
  var fetching = false;
  var active = true;

  Future<void> refresh() async {
    if (!active || fetching || wantedVersion <= deliveredVersion) return;
    fetching = true;
    final requestGeneration = generation;
    final requestedVersion = wantedVersion;
    try {
      final snapshot = await fetchSnapshot();
      if (!active || requestGeneration != generation) return;
      if (snapshot.id != roomId || !snapshot.usesServerCommands) {
        throw StateError('Unexpected command snapshot');
      }
      if (snapshot.serverVersion >= wantedVersion &&
          snapshot.serverVersion > deliveredVersion) {
        deliveredVersion = snapshot.serverVersion;
        controller.add(snapshot);
      }
    } catch (error, stack) {
      if (active && requestGeneration == generation) {
        // A network/permission error is not a deleted room. Keep the last
        // screen intact; the next heartbeat notification can retry the read.
        controller.addError(error, stack);
      }
    } finally {
      fetching = false;
      // Coalesce notifications during a request, without spinning when a
      // read fails or a lagging response hasn't reached the notified version.
      if (active && wantedVersion >= 0 &&
          (wantedVersion > requestedVersion || requestGeneration != generation)) {
        unawaited(refresh());
      }
    }
  }

  controller = StreamController<MatchState?>(
    onListen: () {
      subscription = notifications.listen((publicState) {
        if (publicState == null) {
          generation++;
          wantedVersion = -1;
          deliveredVersion = -1;
          controller.add(null);
          return;
        }
        final version = (publicState['serverVersion'] as num?)?.toInt() ?? 0;
        if (callerUid != null && publicState['playerIds'] is List &&
            !(publicState['playerIds'] as List).contains(callerUid)) {
          generation++;
          wantedVersion = -1;
          // A released seat can no longer fetch its old private hand. Deliver
          // the public removal immediately so the controller clears recovery.
          controller.add(MatchState.fromJson({...publicState, 'handCards': {}}));
          return;
        }
        if (version > wantedVersion) wantedVersion = version;
        unawaited(refresh());
      }, onError: controller.addError);
    },
    onCancel: () async {
      active = false;
      generation++;
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
