import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/lan/domain/lan_protocol.dart';
import 'package:halabessa/features/lan/domain/lan_room.dart';

class FakeLanDriver implements LanGameDriver {
  final events = StreamController<MatchState>.broadcast(sync: true);
  @override
  Stream<MatchState> get changes => events.stream;
  @override
  MatchState? state;
  int commands = 0;
  String? lastUid;
  Completer<void>? held;
  @override
  Future<void> start(
    String room,
    List<LanMember> humans, {
    required String mode,
  }) async {
    final ids = [
      for (final human in humans) human.uid,
      for (var i = humans.length; i < 4; i++) 'bot_$i',
    ];
    state = MatchState(
      id: 'OFFLINE_LAN_$room',
      dealerIndex: 0,
      currentTurnIndex: 1,
      mode: GameMode.values.byName(mode),
      playerIds: ids,
      handCards: {
        for (var i = 0; i < 4; i++)
          ids[i]: [game.Card(game.Suit.values[i], game.Rank.ace)],
      },
      phase: GamePhase.playing,
    );
    events.add(state!);
  }

  @override
  Future<bool> command(
    String uid,
    String action,
    Map<String, dynamic> payload,
  ) async {
    commands++;
    lastUid = uid;
    await held?.future;
    state = state!.copyWith(teamAScore: state!.teamAScore + 1);
    events.add(state!);
    return true;
  }

  @override
  Future<void> presence(String uid, bool connected) async {}
  @override
  Future<void> close() async {
    if (!events.isClosed) await events.close();
  }
}

Map<String, dynamic> request(
  LanRoom room,
  LanMember member, {
  String action = 'play',
  int? revision,
  int? sequence,
  String? id,
}) => {
  'v': lanProtocolVersion,
  'type': 'command',
  'room': room.room,
  'id': id ?? lanSecret(18),
  'seq': sequence ?? member.lastSequence + 1,
  'revision': revision ?? room.revision,
  'action': action,
  'payload': <String, dynamic>{},
};

void main() {
  test(
    'rate rejection does not consume the next sequence; receipts remain idempotent',
    () async {
      final driver = FakeLanDriver();
      final room = LanRoom(
        driver,
        'Host',
        clock: () => DateTime.utc(2026, 10, 26),
      );
      addTearDown(() => room.close('done'));
      await room.start();
      final first = request(room, room.host);
      expect((await room.submit(room.host, first))['ok'], isTrue);
      for (var i = 1; i < 10; i++) {
        expect(
          (await room.submit(room.host, request(room, room.host)))['ok'],
          isTrue,
        );
      }
      final busy = await room.submit(room.host, request(room, room.host));
      expect(busy['reason'], 'lan_busy');
      expect(busy['consumed'], isFalse);
      expect(room.host.lastSequence, 10);
      expect((await room.submit(room.host, first))['ok'], isTrue);
      expect(driver.commands, 10);
    },
  );
  test(
    'a flood is bounded while one accepted command is awaiting completion',
    () async {
      final driver = FakeLanDriver();
      final room = LanRoom(driver, 'Host');
      addTearDown(() => room.close('done'));
      await room.start();
      driver.held = Completer<void>();
      final req = request(room, room.host);
      final queued = [
        for (var i = 0; i < 32; i++) room.submit(room.host, Map.from(req)),
      ];
      final excess = await room.submit(room.host, Map.from(req));
      expect(excess['reason'], 'lan_busy');
      expect(excess['consumed'], isFalse);
      driver.held!.complete();
      expect(await Future.wait(queued), everyElement(containsPair('ok', true)));
      expect(driver.commands, 1);
    },
  );

  test(
    'invitations are native local addresses with a strict identity and pin',
    () {
      final invite = LanInvitation(
        address: '192.168.1.12',
        port: 40101,
        room: lanSecret(18),
        fingerprint: List.filled(64, 'a').join(),
        secret: lanSecret(),
      );
      expect(LanInvitation.parse(invite.text).text, invite.text);
      for (final bad in [
        invite.text.replaceFirst('192.168.1.12', '8.8.8.8'),
        invite.text.replaceFirst('192.168.1.12', '127.0.0.1'),
        invite.text.replaceFirst('192.168.1.12', 'example.com'),
        invite.text.replaceFirst('v=1', 'v=2'),
        '${invite.text}&v=1',
        '${invite.text}#fragment',
        invite.text.replaceFirst('halabessa-lan:', 'https:'),
        invite.text.replaceFirst('40101', '65536'),
        invite.text.replaceFirst('192.168.1.12', '192.168.01.12'),
      ]) {
        expect(() => LanInvitation.parse(bad), throwsFormatException);
      }
      expect(isLocalLanAddress('172.31.255.1'), isTrue);
      expect(isLocalLanAddress('172.32.0.1'), isFalse);
      expect(isLocalLanAddress('10.0.0.1.evil'), isFalse);
      expect(isLocalLanAddress('127.0.0.1', allowLoopback: true), isTrue);
    },
  );

  test(
    'bounded wire parser rejects binary, wrong versions and multibyte overflow',
    () {
      for (final value in [
        [],
        '[]',
        '{"v":2}',
        '{"v":1,"text":"${'ع' * 1024}"}',
      ]) {
        expect(() => lanMessage(value, maxBytes: 2048), throwsFormatException);
      }
      expect(lanName('  أحمد  '), 'أحمد');
      expect(() => lanName('A\nB'), throwsFormatException);
      expect(() => lanName('a' * 31), throwsFormatException);
    },
  );

  test(
    'admission and resume do not allow seat theft or a fifth player',
    () async {
      final room = LanRoom(FakeLanDriver(), 'Host');
      addTearDown(() => room.close('done'));
      expect(() => room.join('wrong', 'Intruder'), throwsStateError);
      final peer = room.join(room.joinSecret, 'Peer');
      room.join(room.joinSecret, 'Third');
      room.join(room.joinSecret, 'Fourth');
      expect(() => room.join(room.joinSecret, 'Fifth'), throwsStateError);
      expect(() => room.resume(peer.resumeToken), throwsStateError);
      room.disconnected(peer);
      expect(() => room.resume(room.joinSecret), throwsStateError);
      expect(room.resume(peer.resumeToken), same(peer));
      await room.start();
      expect(() => room.join(room.joinSecret, 'Late'), throwsStateError);
      expect(jsonEncode(room.view(peer)), isNot(contains(room.joinSecret)));
      expect(jsonEncode(room.view(peer)), isNot(contains(peer.resumeToken)));
    },
  );

  test(
    'every viewer receives exactly their hand and public opponent counts',
    () async {
      final driver = FakeLanDriver(), room = LanRoom(FakeLanDriver(), 'Unused');
      await room.close('done');
      final authority = LanRoom(driver, 'Host');
      addTearDown(() => authority.close('done'));
      final peers = [
        authority.host,
        authority.join(authority.joinSecret, 'B'),
        authority.join(authority.joinSecret, 'C'),
        authority.join(authority.joinSecret, 'D'),
      ];
      await authority.start();
      for (final peer in peers) {
        final projection = authority.view(peer)['match'] as Map;
        expect((projection['handCards'] as Map).keys, [peer.uid]);
        expect((projection['handCounts'] as Map).values, everyElement(1));
        expect(projection['earnedCoins'], isEmpty);
        final parsed = MatchState.fromJson(projection);
        expect(parsed.handCards.keys, [peer.uid]);
      }
      expect(
        () => lanViewerSnapshot(driver.state!, 'outsider'),
        throwsStateError,
      );
    },
  );

  test(
    'duplicate commands are idempotent and a reused identity cannot change payload',
    () async {
      final driver = FakeLanDriver(), room = LanRoom(FakeLanDriver(), 'Unused');
      await room.close('done');
      final authority = LanRoom(driver, 'Host');
      addTearDown(() => authority.close('done'));
      final peer = authority.join(authority.joinSecret, 'Peer');
      await authority.start();
      final req = request(authority, peer);
      final first = await authority.submit(peer, req);
      final duplicate = await authority.submit(peer, Map.from(req));
      expect(first['ok'], isTrue);
      expect(duplicate, first);
      expect(driver.commands, 1);
      final changed = await authority.submit(peer, {...req, 'action': 'show'});
      expect(changed['reason'], 'lan_command_conflict');
      expect(driver.commands, 1);
      final stale = await authority.submit(
        peer,
        request(authority, peer, revision: 0),
      );
      expect(stale['reason'], 'lan_stale');
      expect(stale['consumed'], isTrue);
      expect(driver.commands, 1);
      final forbidden = await authority.submit(
        peer,
        request(authority, peer, action: 'deal'),
      );
      expect(forbidden['ok'], isFalse);
      expect(driver.commands, 1);
    },
  );

  test(
    'concurrent commands serialize against the accepted revision and bind socket identity',
    () async {
      final driver = FakeLanDriver();
      final room = LanRoom(driver, 'Host');
      addTearDown(() => room.close('done'));
      final a = room.join(room.joinSecret, 'A'),
          b = room.join(room.joinSecret, 'B');
      await room.start();
      driver.held = Completer<void>();
      final first = room.submit(a, {...request(room, a), 'uid': b.uid});
      final second = room.submit(b, request(room, b));
      await Future<void>.delayed(Duration.zero);
      expect(driver.commands, 1);
      driver.held!.complete();
      expect((await first)['ok'], isTrue);
      expect(driver.lastUid, a.uid);
      expect((await second)['reason'], 'lan_stale');
      expect(driver.commands, 1);
    },
  );

  test(
    'clock projection preserves elapsed host time without changing source state',
    () {
      final origin = DateTime.utc(2026, 10, 26, 10);
      final state = MatchState(
        id: 'OFFLINE_LAN_test',
        dealerIndex: 0,
        currentTurnIndex: 1,
        mode: GameMode.classic,
        playerIds: const ['A', 'B', 'C', 'D'],
        turnStartTime: origin,
      );
      final original = state.toJson();
      final projected = lanDisplaySnapshot(
        original,
        origin.add(const Duration(seconds: 4)).millisecondsSinceEpoch,
        origin.add(const Duration(hours: 2, seconds: 4)),
      );
      expect(
        projected.turnStartTime!.difference(origin),
        const Duration(hours: 2),
      );
      expect(original['turnStartTime'], origin.toIso8601String());
    },
  );

  test(
    'an explicit player leave ends active play but not an unfinished lobby',
    () async {
      final room = LanRoom(FakeLanDriver(), 'Host');
      addTearDown(() => room.close('done'));
      final peer = room.join(room.joinSecret, 'Peer');
      await room.leave(peer);
      expect(room.members, [room.host]);
      expect(room.closed, isFalse);
      final second = room.join(room.joinSecret, 'Second');
      await room.start();
      room.disconnected(second);
      expect(room.closed, isFalse);
      await room.leave(second);
      expect(room.closed, isTrue);
      expect(room.view(room.host)['match'], isNull);
    },
  );
}
