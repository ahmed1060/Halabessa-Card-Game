import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/providers/unity_communication_service.dart';
import 'package:halabessa/features/game/presentation/providers/unity_layer_provider.dart';
import 'offline_practice_isolation_test.dart' show QuietLocalAudio;

class _RecordingBridge extends UnityCommunicationService {
  _RecordingBridge(super.ref);
  final wire = <Map<String, dynamic>>[];
  @override
  void postMessage(String objectName, String methodName, String message) {
    wire.add(Map<String, dynamic>.from(jsonDecode(message) as Map));
  }
}

final _recordingBridge = Provider<_RecordingBridge>(
  (ref) => _RecordingBridge(ref),
);
const _hand = [
  game.Card(game.Suit.clubs, game.Rank.six),
  game.Card(game.Suit.hearts, game.Rank.nine),
  game.Card(game.Suit.spades, game.Rank.king),
  game.Card(game.Suit.diamonds, game.Rank.ten),
];

void main() {
  testWidgets(
    'background catch-up is silent and future native actions recover',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: 'LOCAL_handoff', email: '', displayName: 'You'),
            audioFactory: (_) => QuietLocalAudio(),
          ),
          unityLayerActiveProvider.overrideWith((_) => true),
        ],
      );
      final bridge = container.read(_recordingBridge);
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      bridge.isReady.value = true;
      bridge.handleUnityMessage(
        jsonEncode({'event': 'UNITY_VISUAL_READY', 'data': '1'}),
      );
      var state = MatchState(
        id: 'OFFLINE_HANDOFF',
        mode: GameMode.classic,
        playerIds: const ['LOCAL_handoff', 'b', 'c', 'd'],
        dealerIndex: 0,
        currentTurnIndex: 0,
        phase: GamePhase.playing,
        roundCount: 2,
        handCards: const {'LOCAL_handoff': _hand},
      );
      bridge.syncState(state);
      await tester.pump();
      state = state.copyWith(serverVersion: 1, board: [_hand[0]]);
      bridge.syncState(state);
      await tester.pump();
      final interrupted = bridge.wire.lastWhere(
        (m) => m['type'] == 'VISUAL_ACTION',
      );
      bridge.setVisualForeground(false);
      bridge.wire.clear();
      state = state.copyWith(serverVersion: 2, board: _hand.take(2).toList());
      bridge.syncState(state);
      // Hidden tabs need not paint a frame to consume accepted catch-up state.
      expect(bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'), isEmpty);
      bridge.handleUnityMessage(
        jsonEncode({
          'event': 'VISUAL_ACTION_COMPLETE',
          'eventId': interrupted['eventId'],
          'generation': interrupted['generation'],
        }),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(bridge.supportsVisualActions, isTrue);
      bridge.setVisualForeground(true);
      await tester.pump();
      expect(bridge.wire.where((m) => m['type'] == 'VISUAL_ACTION'), isEmpty);
      final snapshot = bridge.wire.lastWhere((m) => m['type'] == 'SYNC_STATE');
      expect(snapshot['board'], hasLength(2));
      state = state.copyWith(serverVersion: 3, board: _hand.take(3).toList());
      bridge.syncState(state);
      await tester.pump();
      final next = bridge.wire.lastWhere((m) => m['type'] == 'VISUAL_ACTION');
      expect(next['kind'], 'CardPlayed');
      expect(next['generation'], isNot(interrupted['generation']));
      bridge.handleUnityMessage(
        jsonEncode({
          'event': 'VISUAL_ACTION_COMPLETE',
          'eventId': next['eventId'],
          'generation': next['generation'],
        }),
      );
    },
  );

  for (final leave in [false, true]) {
    testWidgets('native visual handoff uses fresh layout; leave=$leave', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...offlinePlayOverrides(
            prefs,
            AppUser(uid: 'LOCAL_handoff', email: '', displayName: 'You'),
            audioFactory: (_) => QuietLocalAudio(),
          ),
          unityLayerActiveProvider.overrideWith((_) => true),
        ],
      );
      final bridge = container.read(_recordingBridge);
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      bridge.isReady.value = true;
      bridge.handleUnityMessage(
        jsonEncode({'event': 'UNITY_VISUAL_READY', 'data': '1'}),
      );
      final old = MatchState(
        id: 'OFFLINE_HANDOFF',
        mode: GameMode.classic,
        playerIds: const ['LOCAL_handoff', 'b', 'c', 'd'],
        dealerIndex: 0,
        currentTurnIndex: 0,
        phase: GamePhase.playing,
        roundCount: 2,
        handCards: {'LOCAL_handoff': _hand.take(1).toList()},
      );
      bridge.syncState(old);
      await tester.pump();
      bridge.wire.clear();
      bridge.syncState(
        old.copyWith(
          serverVersion: 2,
          phase: GamePhase.dealingCards,
          handCards: {'LOCAL_handoff': _hand},
        ),
      );
      final freshAnchors = [
        for (var i = 0; i < 4; i++)
          {
            'name': 'hand$i',
            'x': .3 + i * .13,
            'y': .85,
            'width': .1,
            'height': .14,
          },
      ];
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => bridge.updateVisualAnchors(freshAnchors),
      );
      if (leave) bridge.clearVisuals();
      await tester.pump();
      final actions = bridge.wire
          .where((m) => m['type'] == 'VISUAL_ACTION')
          .toList();
      if (leave) {
        expect(actions, isEmpty);
        expect(
          bridge.wire.where((m) => m['type'] == 'SYNC_STATE'),
          isEmpty,
          reason: 'leaving must not resurrect a pending old-room hand',
        );
      } else {
        expect(actions, hasLength(1));
        expect(actions.single['kind'], 'CardDrawn');
        expect(actions.single['anchors'], freshAnchors);
        expect(actions.single['handCards'], hasLength(4));
        expect(
          bridge.wire.where((m) => m['type'] == 'SYNC_STATE'),
          isEmpty,
          reason: 'fresh anchors and the new hand must arrive together',
        );
        bridge.handleUnityMessage(
          jsonEncode({
            'event': 'VISUAL_ACTION_COMPLETE',
            'eventId': actions.single['eventId'],
            'generation': actions.single['generation'],
          }),
        );
      }
    });
  }
}
