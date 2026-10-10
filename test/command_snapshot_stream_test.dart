import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/data/repositories/command_snapshot_stream.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;

MatchState snapshot(int version, {String id = 'ROOM1234'}) =>
    MatchState.fromJson({
      'id': id,
      'mode': 'classic',
      'protocolVersion': 1,
      'serverVersion': version,
      'playerIds': ['human'],
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
      notifications: events.stream,
      roomId: 'ROOM1234',
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
    events.add({
      'serverVersion': 3,
      'presence': {'human': true},
    });
    events.add({'serverVersion': 2});
    await flush();
    expect(requests, hasLength(1));
    expect(received.single!.serverVersion, 3);
  });

  Future<(StreamController<MatchState?>, StreamController<MatchState>)>
  usePrivateFeed({MatchState? seed}) async {
    await subscription.cancel();
    await events.close();
    events = StreamController<Map<String, dynamic>?>();
    final own = StreamController<MatchState?>();
    final accepted = StreamController<MatchState>();
    subscription = watchCommandSnapshots(
      notifications: events.stream,
      roomId: 'ROOM1234',
      callerUid: 'human',
      privateSnapshots: own.stream,
      acceptedSnapshots: accepted.stream,
      initialSnapshot: seed,
      recoveryDelay: const Duration(milliseconds: 20),
      fetchSnapshot: () {
        final request = Completer<MatchState>();
        requests.add(request);
        return request.future;
      },
    ).listen(received.add, onError: errors.add);
    addTearDown(() async {
      await subscription.cancel();
      await own.close();
      await accepted.close();
    });
    return (own, accepted);
  }

  test(
    'healthy own views arrive without any per-revision HTTP request',
    () async {
      final (own, accepted) = await usePrivateFeed();
      own.add(snapshot(3)); // Private callback can precede public callback.
      events.add({'serverVersion': 3});
      await flush();
      events.add({'serverVersion': 4});
      own.add(snapshot(4));
      await flush();
      accepted.add(snapshot(4));
      events.add({
        'serverVersion': 4,
        'presence': {'human': true},
      });
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, isEmpty);
      expect(received.map((s) => s?.serverVersion), [3, 4]);
    },
  );

  test(
    'accepted join seed is not removed by the older public membership',
    () async {
      await usePrivateFeed(seed: snapshot(4));
      events.add({
        'serverVersion': 3,
        'playerIds': ['other'],
      });
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, isEmpty);
      expect(received.map((s) => s?.serverVersion), [4]);
      events.add({
        'id': 'ROOM1234',
        'mode': 'classic',
        'protocolVersion': 1,
        'serverVersion': 5,
        'playerIds': ['other'],
      });
      await flush();
      expect(received.last!.playerIds, isNot(contains('human')));
      expect(received.last!.serverVersion, 5);
      events.add({
        'serverVersion': 4,
        'playerIds': ['human'],
      });
      await flush();
      expect(received, hasLength(2));
    },
  );

  test(
    'new private view protects joining seat before first public callback',
    () async {
      final (own, _) = await usePrivateFeed();
      own.add(snapshot(4));
      await flush();
      events.add({
        'serverVersion': 3,
        'playerIds': ['other'],
      });
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, isEmpty);
      expect(received.single!.serverVersion, 4);
    },
  );

  test('unhydrated seed never bypasses fallback', () async {
    await usePrivateFeed(seed: snapshot(4).copyWith(handCounts: {'human': 1}));
    events.add({'serverVersion': 4});
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(received, isEmpty);
    requests.single.complete(snapshot(4));
    await flush();
    expect(received.single!.serverVersion, 4);
  });

  test('incomplete private hand cannot replace a complete revision', () async {
    final (own, _) = await usePrivateFeed();
    events.add({'serverVersion': 4});
    own.add(snapshot(4).copyWith(handCounts: {'human': 1}));
    await flush();
    expect(errors, hasLength(1));
    expect(received, isEmpty);
  });

  test(
    'command response cancels recovery and stale fallback is suppressed',
    () async {
      final (_, accepted) = await usePrivateFeed();
      events.add({'serverVersion': 3});
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, hasLength(1));
      accepted.add(snapshot(4));
      await flush();
      requests.single.complete(snapshot(3));
      await flush();
      expect(received.map((s) => s?.serverVersion), [4]);
      events.add({'serverVersion': 4});
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, hasLength(1));
    },
  );

  test(
    'missing/failed own feed uses bounded recovery, not a deletion',
    () async {
      final (own, _) = await usePrivateFeed();
      events.add({'serverVersion': 2});
      own.add(null);
      own.addError(StateError('permission-denied'));
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(requests, hasLength(1));
      requests.single.complete(snapshot(2));
      await flush();
      expect(received.single!.serverVersion, 2);
      expect(errors, isEmpty);
    },
  );

  test(
    'deleted room ignores late private views and cancels scheduled recovery',
    () async {
      final (own, accepted) = await usePrivateFeed();
      events.add({'serverVersion': 2});
      await flush();
      events.add(null);
      await flush();
      own.add(snapshot(3));
      accepted.add(snapshot(3));
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(received, [null]);
      expect(requests, isEmpty);
    },
  );

  test('wrong room or opponent hand is never accepted from a view', () async {
    final (own, _) = await usePrivateFeed();
    events.add({'serverVersion': 1});
    own.add(snapshot(1, id: 'OTHER123'));
    own.add(
      snapshot(1).copyWith(
        handCards: {
          'opponent': [const game.Card(game.Suit.hearts, game.Rank.ace)],
        },
      ),
    );
    await flush();
    expect(received, isEmpty);
    expect(errors, hasLength(2));
  });

  test(
    'coalesces concurrent notifications and suppresses stale hand/board',
    () async {
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
    },
  );

  test(
    'network failure is an error, not a tombstone, and next event retries',
    () async {
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
    },
  );

  test('actual deletion suppresses an in-flight response', () async {
    events.add({'serverVersion': 3});
    await flush();
    events.add(null);
    await flush();
    requests.first.complete(snapshot(3));
    await flush();
    expect(received, [null]);
  });

  test(
    'recreated room cannot receive the previous generation response',
    () async {
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
    },
  );

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

  test(
    'kick delivers public removal without fetching forbidden former hand',
    () async {
      events.add({
        'id': 'ROOM1234',
        'mode': 'classic',
        'protocolVersion': 1,
        'serverVersion': 4,
        'playerIds': ['bot_0', 'bot_1', 'bot_2', 'bot_3'],
        'handCards': {
          'human': [
            {'suit': 'hearts', 'rank': 'ace'},
          ],
        },
      });
      await flush();
      expect(requests, isEmpty);
      expect(received.single!.playerIds, isNot(contains('human')));
      expect(received.single!.handCards, isEmpty);
    },
  );
}
