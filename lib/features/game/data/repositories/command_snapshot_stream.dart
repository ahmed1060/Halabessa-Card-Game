import 'dart:async';

import '../../domain/models/match_state.dart';

/// Prefer atomic own-hand realtime views and reuse accepted command responses.
/// Public notifications supply removal/recovery, never private cards. Older
/// mirrors and broken feeds fall back to the authenticated snapshot endpoint.
Stream<MatchState?> watchCommandSnapshots({
  required Stream<Map<String, dynamic>?> notifications,
  required Future<MatchState> Function() fetchSnapshot,
  required String roomId,
  String? callerUid,
  Stream<MatchState?>? privateSnapshots,
  Stream<MatchState>? acceptedSnapshots,
  MatchState? initialSnapshot,
  Duration recoveryDelay = const Duration(milliseconds: 500),
  List<Duration> recoveryRetryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ],
}) {
  late StreamController<MatchState?> controller;
  StreamSubscription<Map<String, dynamic>?>? subscription;
  StreamSubscription<MatchState?>? privateSubscription;
  StreamSubscription<MatchState>? acceptedSubscription;
  Timer? recovery;
  MatchState? candidate;
  var haveRoom = false;
  var seenPublic = false;
  var released = false;
  var generation = 0;
  var wantedVersion = -1;
  var deliveredVersion = -1;
  var fetching = false;
  var active = true;
  var recoveryRetries = 0;
  final retryDelays = List<Duration>.unmodifiable(recoveryRetryDelays);

  bool validSnapshot(MatchState snapshot) =>
      snapshot.id == roomId &&
      snapshot.usesServerCommands &&
      snapshot.serverVersion >= 0 &&
      (callerUid == null ||
          (!snapshot.handCards.keys.any((uid) => uid != callerUid) &&
              (snapshot.handCards[callerUid]?.length ?? 0) ==
                  (snapshot.handCounts[callerUid] ?? 0)));

  void accept(MatchState snapshot) {
    if (!active || !haveRoom || released) return;
    if (!validSnapshot(snapshot)) {
      controller.addError(StateError('Unexpected command snapshot'));
      return;
    }
    if (snapshot.serverVersion < wantedVersion ||
        snapshot.serverVersion <= deliveredVersion) {
      return;
    }
    deliveredVersion = snapshot.serverVersion;
    recoveryRetries = 0;
    recovery?.cancel();
    controller.add(snapshot);
  }

  void offer(MatchState snapshot) {
    if (!active || released || (seenPublic && !haveRoom)) return;
    if (!validSnapshot(snapshot)) {
      controller.addError(StateError('Unexpected command snapshot'));
      return;
    }
    if (candidate == null ||
        snapshot.serverVersion > candidate!.serverVersion) {
      candidate = snapshot;
    }
    accept(snapshot);
  }

  Future<void> refresh() async {
    if (!active ||
        !haveRoom ||
        released ||
        fetching ||
        wantedVersion <= deliveredVersion) {
      return;
    }
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
        accept(snapshot);
      }
    } catch (error, stack) {
      if (active && requestGeneration == generation) {
        // A network/permission error is not a deleted room. Keep the last
        // screen intact. Bounded backoff below also recovers when no further
        // heartbeat arrives; only authenticated snapshot reads are retried.
        controller.addError(error, stack);
      }
    } finally {
      fetching = false;
      // Coalesce notifications during a request, without spinning when a
      // read fails or a lagging response hasn't reached the notified version.
      if (active &&
          haveRoom &&
          !released &&
          wantedVersion >= 0 &&
          (wantedVersion > requestedVersion ||
              requestGeneration != generation)) {
        recoveryRetries = 0;
        recovery?.cancel();
        unawaited(refresh());
      } else if (active &&
          haveRoom &&
          !released &&
          requestGeneration == generation &&
          wantedVersion > deliveredVersion &&
          recoveryRetries < retryDelays.length) {
        recovery?.cancel();
        recovery = Timer(
          retryDelays[recoveryRetries++],
          () => unawaited(refresh()),
        );
      }
    }
  }

  void scheduleRecovery() {
    if (!active || !haveRoom || released || wantedVersion <= deliveredVersion) {
      return;
    }
    if (privateSnapshots == null) {
      unawaited(refresh());
    } else if (recovery?.isActive != true) {
      // Root PATCH listener ordering is not guaranteed. Give the private view
      // a chance to arrive before starting a redundant HTTP read.
      recovery = Timer(recoveryDelay, () => unawaited(refresh()));
    }
  }

  controller = StreamController<MatchState?>(
    onListen: () {
      // Reuse the authenticated create/join/reconnect response, but never seed
      // a public board whose positive own-hand count has not been hydrated.
      final seed = initialSnapshot;
      if (seed != null &&
          validSnapshot(seed) &&
          (callerUid == null || seed.playerIds.contains(callerUid))) {
        haveRoom = true;
        offer(seed);
      }
      subscription = notifications.listen((publicState) {
        seenPublic = true;
        if (publicState == null ||
            (publicState['__halabessaDelivery'] is Map &&
                (publicState['__halabessaDelivery'] as Map)['deleted'] ==
                    true)) {
          generation++;
          haveRoom = false;
          released = false;
          candidate = null;
          recovery?.cancel();
          wantedVersion = -1;
          deliveredVersion = -1;
          recoveryRetries = 0;
          controller.add(null);
          return;
        }
        final version = (publicState['serverVersion'] as num?)?.toInt() ?? 0;
        haveRoom = true;
        // Public membership can lag behind a committed join response/private
        // view. Only a same-or-newer revision can remove the current seat.
        if (version < deliveredVersion ||
            version < (candidate?.serverVersion ?? -1)) {
          if (candidate != null) accept(candidate!);
          return;
        }
        if (callerUid != null &&
            publicState['playerIds'] is List &&
            !(publicState['playerIds'] as List).contains(callerUid)) {
          generation++;
          released = true;
          candidate = null;
          recovery?.cancel();
          wantedVersion = -1;
          deliveredVersion = version;
          // A released seat can no longer fetch its old private hand. Deliver
          // the public removal immediately so the controller clears recovery.
          controller.add(
            MatchState.fromJson({...publicState, 'handCards': {}}),
          );
          return;
        }
        released = false;
        if (version > wantedVersion) {
          wantedVersion = version;
          recoveryRetries = 0;
        }
        if (candidate != null) accept(candidate!);
        scheduleRecovery();
      }, onError: controller.addError);
      privateSubscription = privateSnapshots?.listen(
        (snapshot) {
          if (snapshot != null) {
            offer(snapshot);
          } else {
            scheduleRecovery(); // Missing private view is not a deleted room.
          }
        },
        onError: (Object error, StackTrace stack) {
          // The authenticated fallback also works during a compatible rollout
          // where the older rules don't yet allow the new private child.
          scheduleRecovery();
        },
      );
      acceptedSubscription = acceptedSnapshots?.listen(
        offer,
        onError: controller.addError,
      );
    },
    onCancel: () async {
      active = false;
      generation++;
      recovery?.cancel();
      await Future.wait([
        if (subscription != null) subscription!.cancel(),
        if (privateSubscription != null) privateSubscription!.cancel(),
        if (acceptedSubscription != null) acceptedSubscription!.cancel(),
      ]);
    },
  );
  return controller.stream;
}
