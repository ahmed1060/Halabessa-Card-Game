import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/native_play_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/presentation/providers/unity_communication_service.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'package:halabessa/features/game/presentation/widgets/unity_game_view.dart';
import 'package:halabessa/features/lan/presentation/lan_play_app.dart';
import '../tool/lan_review_fixtures.dart';
import 'table_chat_ui_test.dart' show host;

class _Bridge extends UnityCommunicationService {
  _Bridge(super.ref);
  final wire = <Map<String, dynamic>>[];
  @override
  void init() {} // Explicit handshake/failure in tests; no platform/timeouts.
  @override
  void postMessage(String object, String method, String message) {
    wire.add(Map<String, dynamic>.from(jsonDecode(message) as Map));
  }

  void event(String name, [String data = '1']) =>
      handleUnityMessage(jsonEncode({'event': name, 'data': data}));
}

class _Connection extends ReviewLanConnection {
  final commands = <Map<String, dynamic>>[];
  @override
  Future<bool> command(String action, Map<String, dynamic> payload) async {
    commands.add({'action': action, 'payload': payload});
    return false; // Definite rejection must never optimistically mutate state.
  }
}

class _MountCounter extends StatefulWidget {
  const _MountCounter(this.onMount);
  final VoidCallback onMount;
  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const UnityGameView(
    nativeView: SizedBox(key: ValueKey('fake-native-view')),
  );
}

void main() {
  testWidgets(
    'LAN Unity uses its private replica, gates readiness and routes intents',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connection = _Connection()..table();
      late _Bridge bridge;
      var mounts = 0;
      await host(
        tester,
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // A previously initialized/failed online renderer must not be inherited.
            unityInitializedProvider.overrideWith((_) => true),
            unityFailedProvider.overrideWith((_) => true),
          ],
          child: LanPlayApp(
            preferences: prefs,
            player: AppUser(
              uid: 'LOCAL_profile_not_seat',
              email: '',
              displayName: 'You',
            ),
            onExit: () {},
            unityEnabled: true,
            unityView: _MountCounter(() => mounts++),
            bridgeFactory: (ref) => bridge = _Bridge(ref),
            discoveryFactory: ReviewLanDiscovery.new,
            joinFactory: (_, __) async => connection,
            audioFactory: (_) => ReviewLanAudio(),
          ),
        ),
      );
      expect(mounts, 0, reason: 'no native view in entry/lobby');
      await tester.tap(find.byKey(const ValueKey('lan-browse')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        ReviewLanHost().invitation('192.168.1.20').text,
      );
      final join = find.widgetWithText(FilledButton, 'Join a room');
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameBoardScreen)),
        listen: false,
      );
      expect(container.read(localUnityEnabledProvider), isTrue);
      expect(container.read(unityLayerVisibilityProvider), isTrue);
      expect(container.read(unityLayerActiveProvider), isFalse);
      expect(mounts, 1);
      bridge.requestNativeReady();
      expect(bridge.wire.last['type'], 'REQUEST_READY');
      bridge.event('UNITY_READY');
      bridge.event('UNITY_CARD_UI_READY');
      await tester.pump();
      expect(container.read(unityLayerActiveProvider), isTrue);
      expect(container.read(unityCardUiReadyProvider), isTrue);
      final sync = bridge.wire.lastWhere((m) => m['type'] == 'SYNC_STATE');
      final source = connection.snapshot!['match'] as Map;
      expect(sync['handCards'], source['handCards'][connection.uid]);
      expect(sync['board'], source['board']);
      expect(sync.containsKey('members'), isFalse);
      expect(
        container.read(matchStateProvider)!.serverVersion,
        connection.snapshot!['revision'],
      );
      final untouched = jsonEncode(connection.snapshot);
      bridge.event('PLAY_CARD', 'clubs_six');
      await tester.pump();
      expect(connection.commands.single['action'], 'play');
      expect(connection.commands.single['payload']['card'], {
        'suit': 'clubs',
        'rank': 'six',
      });
      expect(jsonEncode(connection.snapshot), untouched);
      expect(Firebase.apps, isEmpty);

      var match = Map<String, dynamic>.from(source);
      void nextCard(String rank) {
        match = {
          ...match,
          'board': [
            ...match['board'] as List,
            {'suit': 'hearts', 'rank': rank},
          ],
        };
        connection.publish({'match': match});
      }

      bridge.wire.clear();
      nextCard('two');
      await tester.pump();
      expect(
        bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION').single['kind'],
        'CardPlayed',
      );
      final interrupted = bridge.wire.lastWhere(
        (m) => m['type'] == 'VISUAL_ACTION',
      );
      connection.status = 'reconnecting';
      connection.notifyListeners();
      bridge.wire.clear();
      nextCard('three');
      await tester.pump();
      expect(container.read(unityVisualSuspendedProvider), isTrue);
      expect(bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'), isEmpty);
      connection.status = 'connected';
      connection.publish({'match': match});
      await tester.pump();
      await tester.pump();
      expect(container.read(unityVisualSuspendedProvider), isFalse);
      expect(
        bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'),
        isEmpty,
        reason: 'reconnect catches up without replaying missed effects',
      );
      bridge.handleUnityMessage(
        jsonEncode({
          'event': 'VISUAL_ACTION_COMPLETE',
          'eventId': interrupted['eventId'],
          'generation': interrupted['generation'],
        }),
      );
      nextCard('four');
      await tester.pump();
      expect(
        bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'),
        hasLength(1),
      );
      expect(mounts, 1, reason: 'reconnect reuses the same native view');

      final beforeResize = jsonEncode(connection.snapshot);
      bridge.wire.clear();
      bridge.event('UNITY_VIEWPORT_CHANGED', '');
      await tester.pump();
      expect(
        bridge.wire.where((m) => m['type'] == 'CANCEL_VISUALS'),
        isNotEmpty,
      );
      expect(
        bridge.wire.where((m) => m['type'] == 'SYNC_STATE').last['board'],
        match['board'],
      );
      expect(jsonEncode(connection.snapshot), beforeResize);
      expect(container.read(unityLayerActiveProvider), isTrue);
      nextCard('five');
      await tester.pump();
      expect(
        bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'),
        hasLength(1),
        reason: 'camera resize reconciles without disabling later actions',
      );

      await container.read(settingsProvider.notifier).toggle3DMode(false);
      await tester.pump();
      expect(container.read(unityLayerActiveProvider), isFalse);
      await container.read(settingsProvider.notifier).toggle3DMode(true);
      await tester.pump();
      expect(container.read(unityLayerActiveProvider), isTrue);
      expect(mounts, 1);
      bridge.event('UNITY_FAILED');
      await tester.pump();
      expect(container.read(unityLayerActiveProvider), isFalse);
      bridge.event('UNITY_READY');
      expect(container.read(unityLayerActiveProvider), isFalse);
      expect(find.byType(GameBoardScreen), findsOneWidget);
      expect(Firebase.apps, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      bridge.event(
        'UNITY_READY',
      ); // Late callback after scope disposal is inert.
      expect(tester.takeException(), isNull);
    },
  );
}
