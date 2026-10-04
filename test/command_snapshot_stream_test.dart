import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/data/repositories/command_snapshot_stream.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

MatchState snapshot(int version, {String id = 'ROOM1234'}) => MatchState.fromJson({
  'id': id, 'mode': 'classic', 'protocolVersion': 1,
  'serverVersion': version, 'playerIds': ['human'],
});

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<Map<String, dynamic>?> events;
  late List<Completer<MatchState>> requests;
  late List<MatchState?> received;
  late List<Object> errors;
  late StreamSubscription<MatchState?> subscription;

  setUp(() {
    events = StreamController<Map<String, dynamic>?>();
    requests = [];
    received = [];
    errors = [];
    subscription = watchCommandSnapshots(
      notifications: events.stream, roomId: 'ROOM1234',
      callerUid: 'human',
      fetchSnapshot: () {
        final request = Completer<MatchState>();
        requests.add(request);
        return request.future;
      },
    ).listen(received.add, onError: errors.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await events.close();
  });

  test('heartbeats on a delivered revision do not refetch', () async {
    events.add({'serverVersion': 3});
    await flush();
    requests.single.complete(snapshot(3));
    await flush();
    events.add({'serverVersion': 3, 'presence': {'human': true}});
    events.add({'serverVersion': 2});
    await flush();
    expect(requests, hasLength(1));
    expect(received.single!.serverVersion, 3);
  });

  test('coalesces concurrent notifications and suppresses stale hand/board', () async {
    events.add({'serverVersion': 3});
    await flush();
    events.add({'serverVersion': 4});
    events.add({'serverVersion': 5});
    await flush();
    expect(requests, hasLength(1));
    requests.first.complete(snapshot(3));
    await flush();
    expect(received, isEmpty);
    expect(requests, hasLength(2));
    requests.last.complete(snapshot(5));
    await flush();
    expect(received.single!.serverVersion, 5);
  });

  test('network failure is an error, not a tombstone, and next event retries', () async {
    events.add({'serverVersion': 3});
    await flush();
    requests.first.completeError(StateError('offline'));
    await flush();
    expect(received, isEmpty);
    expect(errors, hasLength(1));
    expect(requests, hasLength(1));
    events.add({'serverVersion': 3});
    await flush();
    requests.last.complete(snapshot(3));
    await flush();
    expect(received.single!.serverVersion, 3);
  });

  test('actual deletion suppresses an in-flight response', () async {
    events.add({'serverVersion': 3});
    await flush();
    events.add(null);
    await flush();
    requests.first.complete(snapshot(3));
    await flush();
    expect(received, [null]);
  });

  test('recreated room cannot receive the previous generation response', () async {
    events.add({'serverVersion': 3});
    await flush();
    events.add(null);
    events.add({'serverVersion': 0});
    await flush();
    requests.first.complete(snapshot(3));
    await flush();
    expect(requests, hasLength(2));
    requests.last.complete(snapshot(0));
    await flush();
    expect(received.map((s) => s?.serverVersion), [null, 0]);
  });

  test('cancellation discards pending completion', () async {
    events.add({'serverVersion': 3});
    await flush();
    await subscription.cancel();
    requests.single.complete(snapshot(3));
    await flush();
    expect(received, isEmpty);
  });

  test('wrong-room response never reaches the controller', () async {
    events.add({'serverVersion': 3});
    await flush();
    requests.single.complete(snapshot(3, id: 'OTHER123'));
    await flush();
    expect(received, isEmpty);
    expect(errors, hasLength(1));
  });

  test('kick delivers public removal without fetching forbidden former hand', () async {
    events.add({'id': 'ROOM1234', 'mode': 'classic', 'protocolVersion': 1,
      'serverVersion': 4, 'playerIds': ['bot_0', 'bot_1', 'bot_2', 'bot_3'],
      'handCards': {'human': [{'suit': 'hearts', 'rank': 'ace'}]}});
    await flush();
    expect(requests, isEmpty);
    expect(received.single!.playerIds, isNot(contains('human')));
    expect(received.single!.handCards, isEmpty);
  });
}
