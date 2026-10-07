import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool hasFreshPresence(Object? value, DateTime now) {
  if (value is! Map) return false;
  return value.values.any((connection) {
    if (connection is! Map || connection['lastSeen'] is! num) return false;
    final age =
        now.millisecondsSinceEpoch - (connection['lastSeen'] as num).toInt();
    return age >= -5000 && age <= 75000;
  });
}

final presenceServerOffsetProvider = StreamProvider.autoDispose<int>(
  (ref) => FirebaseDatabase.instance
      .ref('.info/serverTimeOffset')
      .onValue
      .map(
        (event) => event.snapshot.value is num
            ? (event.snapshot.value as num).toInt()
            : 0,
      ),
);
final presenceClockProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  // Heartbeats use server timestamps; compare with server-adjusted time even if
  // a phone's wall clock is wrong. This does not authorize gameplay actions.
  final offset = ref.watch(presenceServerOffsetProvider).valueOrNull ?? 0;
  DateTime now() => DateTime.now().add(Duration(milliseconds: offset));
  yield now();
  yield* Stream.periodic(const Duration(seconds: 15), (_) => now());
});
final playerPresenceProvider = StreamProvider.autoDispose
    .family<Object?, String>(
      (ref, uid) => FirebaseDatabase.instance
          .ref('userPresence')
          .child(uid)
          .onValue
          .map((event) => event.snapshot.value),
    );

/// One connection record per app/tab; another device is not marked offline on exit.
class PlayerPresenceSession extends StatefulWidget {
  final String uid;
  final Widget child;
  const PlayerPresenceSession({
    super.key,
    required this.uid,
    required this.child,
  });
  @override
  State<PlayerPresenceSession> createState() => _PlayerPresenceSessionState();
}

class _PlayerPresenceSessionState extends State<PlayerPresenceSession>
    with WidgetsBindingObserver {
  StreamSubscription<DatabaseEvent>? _connected;
  DatabaseReference? _record;
  Timer? _heartbeat;
  bool _active = true, _online = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _record = FirebaseDatabase.instance
        .ref('userPresence')
        .child(widget.uid)
        .push();
    _connected = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) {
          _online = event.snapshot.value == true;
          if (_online && _active) unawaited(_publish());
        });
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_active && _online) unawaited(_publish());
    });
  }

  Future<void> _publish() async {
    try {
      await _record!.onDisconnect().remove();
      if (!mounted || !_active || !_online) return;
      await _record!.set({'lastSeen': ServerValue.timestamp});
      if (!mounted || !_active) await _record!.remove();
    } catch (_) {
      /* Presence failure must not interrupt gameplay. */
    }
  }

  Future<void> _remove() async {
    try {
      await _record?.remove();
    } catch (_) {
      /* Stale records expire visually. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && _online) {
      unawaited(_publish());
    } else {
      unawaited(_remove());
    }
  }

  @override
  void dispose() {
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    unawaited(_connected?.cancel() ?? Future<void>.value());
    unawaited(_remove());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
