import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/models/game_action.dart';
import 'package:halabessa/features/game/domain/logic/game_engine.dart';
import 'package:halabessa/features/game/domain/models/card_feature_state.dart';
import 'package:halabessa/features/lan/data/lan_connection.dart';
import 'package:halabessa/features/lan/data/lan_socket_transport.dart';
import 'package:halabessa/features/lan/domain/lan_protocol.dart';
import 'package:halabessa/features/lan/presentation/lan_match_adapter.dart';
import 'lan_protocol_test.dart' show FakeLanDriver;

Future<void> waitFor(LanConnection connection, bool Function() ready) async {
  if (ready()) return;
  final done = Completer<void>();
  void check() {
    if (!done.isCompleted && ready()) done.complete();
  }

  connection.addListener(check);
  try {
    await done.future.timeout(const Duration(seconds: 18));
  } finally {
    connection.removeListener(check);
  }
}

Future<(WebSocket, HttpClient)> rawSocket(LanInvitation invite) async {
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
  client.badCertificateCallback = (cert, host, port) =>
      host == invite.address &&
      port == invite.port &&
      sha256.convert(cert.der).toString() == invite.fingerprint;
  final socket = await WebSocket.connect(
    'wss://${invite.address}:${invite.port}/room',
    protocols: [lanSocketProtocol],
    customClient: client,
  );
  return (socket, client);
}

class _RealLoopbackHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These are actual TLS tests, not widget network-image requests.
  final priorHttp = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = _RealLoopbackHttp());
  tearDownAll(() => HttpOverrides.global = priorHttp);
  test(
    'real pinned TLS rejects wrong certificate identity and wrong invitation secret',
    () async {
      final host = await hostLanRoom(
        FakeLanDriver(),
        'Host',
        loopbackForTesting: true,
      );
      addTearDown(host.close);
      final invite = host.invitation('127.0.0.1');
      await expectLater(
        joinLanRoom(
          LanInvitation(
            address: invite.address,
            port: invite.port,
            room: invite.room,
            fingerprint: '0' * 64,
            secret: invite.secret,
          ),
          'Wrong pin',
          loopbackForTesting: true,
        ),
        throwsA(anything),
      );
      await expectLater(
        joinLanRoom(
          LanInvitation(
            address: invite.address,
            port: invite.port,
            room: invite.room,
            fingerprint: invite.fingerprint,
            secret: lanSecret(),
          ),
          'Wrong secret',
          loopbackForTesting: true,
        ),
        throwsA(anything),
      );
      final valid = await joinLanRoom(
        invite,
        'Valid',
        loopbackForTesting: true,
      );
      expect(valid.status, 'connected');
      await valid.close();
      valid.dispose();
    },
  );

  test(
    'a private resume credential reclaims only its original seat over a fresh TLS socket',
    () async {
      final host = await hostLanRoom(
        FakeLanDriver(),
        'Host',
        loopbackForTesting: true,
      );
      addTearDown(host.close);
      final invite = host.invitation('127.0.0.1');
      final (socket, http) = await rawSocket(invite);
      final messages = StreamIterator(socket);
      socket.add(
        jsonEncode({
          'v': 1,
          'type': 'hello',
          'room': invite.room,
          'secret': invite.secret,
          'name': 'Peer',
        }),
      );
      expect(await messages.moveNext(), isTrue);
      final welcome = lanMessage(messages.current);
      await socket.close();
      await messages.cancel();
      http.close(force: true);
      await waitFor(
        host.local,
        () => (host.local.snapshot!['members'] as List).whereType<Map>().any(
          (m) => m['uid'] == welcome['uid'] && m['connected'] == false,
        ),
      );
      final (second, secondHttp) = await rawSocket(invite);
      final resumed = StreamIterator(second);
      second.add(
        jsonEncode({
          'v': 1,
          'type': 'hello',
          'room': invite.room,
          'resume': welcome['resume'],
          'uid': 'spoofed',
          'name': 'Changed',
        }),
      );
      expect(await resumed.moveNext(), isTrue);
      expect(lanMessage(resumed.current)['uid'], welcome['uid']);
      expect((host.local.snapshot!['members'] as List).length, 2);
      await second.close();
      await resumed.cancel();
      secondHttp.close(force: true);
    },
  );

  test(
    'four real connections reuse the engine, preserve private hands and accept remote reveal/slam',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final driver = LanMatchDriver(
        preferences,
        AppUser(uid: 'LOCAL_profile', email: '', displayName: 'Host'),
      );
      final host = await hostLanRoom(driver, 'Host', loopbackForTesting: true);
      final peers = <LanConnection>[];
      addTearDown(() async {
        for (final peer in peers) {
          await peer.close(leave: false);
          peer.dispose();
        }
        await host.close();
      });
      for (final name in ['Second', 'Third', 'Fourth']) {
        peers.add(
          await joinLanRoom(
            host.invitation('127.0.0.1'),
            name,
            loopbackForTesting: true,
          ),
        );
      }
      await expectLater(
        joinLanRoom(
          host.invitation('127.0.0.1'),
          'Fifth',
          loopbackForTesting: true,
        ),
        throwsA(anything),
      );
      await host.start();
      await waitFor(
        host.local,
        () => driver.state?.phase == GamePhase.preRoundCut,
      );
      expect(await host.local.command('cut', {'position': 20}), isTrue);
      await waitFor(
        peers.first,
        () =>
            driver.state?.phase == GamePhase.playing &&
            peers.first.snapshot?['match']?['phase'] == 'playing',
      );
      for (final peer in [host.local, ...peers]) {
        final data = peer.snapshot!['match'] as Map;
        expect((data['handCards'] as Map).keys, [peer.uid]);
        expect((data['handCounts'] as Map).values, everyElement(4));
        expect(data['earnedCoins'], isEmpty);
        expect(data['earnedStars'], isEmpty);
      }
      expect(Firebase.apps, isEmpty);
      final revealer = peers[1];
      await waitFor(
        revealer,
        () => revealer.snapshot?['match']?['phase'] == 'playing',
      );
      final revealCard = driver.state!.handCards[revealer.uid]!.first;
      expect(
        await revealer.command('show', {'card': revealCard.toJson()}),
        isTrue,
      );
      expect(driver.state!.handCards[revealer.uid], contains(revealCard));
      expect(CardFeatureState(driver.state!).remaining(revealer.uid), 2);
      await waitFor(
        peers.first,
        () =>
            (peers.first.snapshot!['revision'] as int) >=
            (revealer.snapshot!['revision'] as int),
      );
      final actor = peers.first;
      final card = driver.state!.handCards[actor.uid]!.first;
      final expected = GameEngine.apply(
        driver.state!,
        PlayCardAction(actor.uid, card),
      ).newState;
      expect(
        await actor.command('play', {'card': card.toJson(), 'slam': true}),
        isTrue,
      );
      expect(driver.state!.handCards[actor.uid], isNot(contains(card)));
      expect(driver.state!.board, expected.board);
      expect(driver.state!.handCards, expected.handCards);
      expect(driver.state!.teamAScore, expected.teamAScore);
      expect(driver.state!.teamBScore, expected.teamBScore);
      expect(driver.state!.currentTurnIndex, expected.currentTurnIndex);
      expect(
        CardFeatureState(driver.state!).remaining(actor.uid, slam: true),
        2,
      );
      expect(driver.state!.earnedCoins, isEmpty);
      expect(driver.state!.earnedStars, isEmpty);
      expect(Firebase.apps, isEmpty);
      final originalUid = actor.uid;
      await actor.suspend();
      await waitFor(
        host.local,
        () => (host.local.snapshot!['members'] as List).whereType<Map>().any(
          (m) => m['uid'] == actor.uid && m['connected'] == false,
        ),
      );
      expect(actor.status, 'reconnecting');
      expect(driver.state!.playerOnlineStatus[actor.uid], isFalse);
      await actor.reconnect();
      expect(actor.uid, originalUid);
      expect(actor.status, 'connected');
      expect(driver.state!.playerOnlineStatus[actor.uid], isTrue);
      expect((actor.snapshot!['match']['handCards'] as Map).keys, [actor.uid]);
      await host.close();
      await waitFor(actor, () => actor.status == 'ended');
      expect(actor.snapshot!['closed'], isTrue);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
