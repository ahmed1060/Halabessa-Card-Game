import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/providers/native_play_provider.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/services/default_audio_assets.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/widgets/native_play_entry.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/bot_difficulty.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_controls.dart';
import 'package:halabessa/features/game/presentation/providers/chat_providers.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

class QuietLocalAudio extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playMusic(String assetPath, {bool loop = true}) async {}
  @override
  Future<void> playRoomMusic(String assetPath, {bool loop = true}) async {}
  @override
  void handleInteraction() {}
  @override
  Future<void> playSfx(String assetPath) async {}
  @override
  Future<void> vibrate() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const localUid = 'LOCAL_qa';
  final player = AppUser(uid: localUid, email: '', displayName: 'Local');

  Future<ProviderContainer> setup() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...offlinePlayOverrides(
          prefs,
          player,
          audioFactory: (_) => QuietLocalAudio(),
        ),
      ],
    );
  }

  testWidgets('fresh signed-out local scope reads no cloud dependencies', (
    tester,
  ) async {
    final c = await setup();
    expect(c.read(currentUserProvider)!.uid, localUid);
    expect(c.read(sessionUidProvider), isNull);
    expect(c.read(globalSettingsProvider).musicOverrideUrl, isNull);
    expect(c.read(activeTableSkinProvider).assetPath, startsWith('assets/'));
    expect(c.read(activeCardBackProvider).assetPath, startsWith('assets/'));
    expect(c.read(storeProvider).extraItems, isEmpty);
    final auth = c.listen(authStateChangesProvider, (_, __) {});
    await tester.pump();
    expect(c.read(authStateChangesProvider).value, isNull);
    auth.close();
    c.dispose();
  });

  testWidgets(
    'real signed-out board accepts a tap and hides the banner on other turns',
    (tester) async {
      final c = await setup();
      const card = cards.Card(cards.Suit.clubs, cards.Rank.two);
      const nextCard = cards.Card(cards.Suit.hearts, cards.Rank.three);
      final n = c.read(matchStateProvider.notifier);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = MatchState(
        id: 'OFFLINE_UI_QA',
        mode: GameMode.classic,
        playerIds: [localUid, 'bot_1', 'bot_2', 'bot_3'],
        dealerIndex: 0,
        currentTurnIndex: 0,
        phase: GamePhase.playing,
        turnStartTime: DateTime.now(),
        handCards: {
          localUid: [card, nextCard],
          'bot_1': [nextCard, card],
          'bot_2': [nextCard, card],
          'bot_3': [nextCard, card],
        },
      );
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: GameBoardScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(LanternTurnBadge), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('hand-card-${card.firebaseKey}')));
      await tester.pump();
      expect(c.read(matchStateProvider)!.board, [card]);
      expect(c.read(matchStateProvider)!.handCards[localUid], [nextCard]);
      expect(find.byType(LanternTurnBadge), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(seconds: 15));
      expect(tester.takeException(), isNull);
    },
  );

  for (final level in BotDifficulty.values) {
    testWidgets(
      'signed-out ${level.name} Practice deals locally and can leave',
      (tester) async {
        final c = await setup();
        final n = c.read(matchStateProvider.notifier);
        n.startOfflinePracticeMatch(localUid, 'Local', difficulty: level);
        // The randomly cut bottom card may trigger either reveal path. Wait for
        // the real phase, without assuming one particular shuffle/deck shape.
        for (
          var tick = 0;
          tick < 60 && c.read(matchStateProvider)?.phase != GamePhase.playing;
          tick++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        final s = c.read(matchStateProvider)!;
        expect(s.phase, GamePhase.playing);
        expect(s.id, startsWith('OFFLINE_'));
        expect(s.usesServerCommands, isFalse);
        expect(s.handCards[localUid], hasLength(4));
        expect(s.botDifficulties.values.toSet(), {level.name});
        final subscription = c.listen(chatMessagesProvider, (_, __) {});
        await tester.pump();
        expect(c.read(chatMessagesProvider).value, isEmpty);
        subscription.close();
        expect(await n.leaveMatch(), isTrue);
        expect(c.read(matchStateProvider), isNull);
        c.dispose();
        await tester.pump(const Duration(seconds: 15));
      },
    );
  }

  testWidgets(
    'Practice completion never needs Firestore or awards online coins',
    (tester) async {
      final c = await setup();
      const card = cards.Card(cards.Suit.clubs, cards.Rank.two);
      final n = c.read(matchStateProvider.notifier);
      // End-of-round fixture, with every other hand already played.
      // No Firebase app is initialized in this test: a reward write would fail.
      final s = MatchState(
        id: 'OFFLINE_REWARD_QA',
        mode: GameMode.classic,
        maxPoints: 1,
        playerIds: [localUid, 'bot_1', 'bot_2', 'bot_3'],
        dealerIndex: 0,
        currentTurnIndex: 0,
        phase: GamePhase.playing,
        teamAScore: 3,
        handInRound: 3,
        deckCount: 0,
        handCards: {
          localUid: [card],
          'bot_1': [],
          'bot_2': [],
          'bot_3': [],
        },
        lastCaptureTeam: 'teamA',
      );
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      n.state = s;
      final pending = n.playCard(localUid, card);
      await tester.pump();
      expect(c.read(matchStateProvider)!.phase, GamePhase.roundScoring);
      await tester.pump(const Duration(seconds: 8));
      await pending;
      expect(c.read(matchStateProvider)!.phase, GamePhase.rematchVoting);
      expect(c.read(matchStateProvider)!.earnedCoins, isEmpty);
      expect(c.read(matchStateProvider)!.earnedStars, isEmpty);
      expect(tester.takeException(), isNull);
      c.dispose();
      await tester.pump(const Duration(seconds: 15));
    },
  );

  testWidgets('native entry allows local mode even while Online cannot start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final online = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: NativePlayEntry(onOnline: () => online.future),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('native-online')));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NativePlayEntry)),
      listen: false,
    );
    // Also cover a completed choice whose root frame has not switched yet.
    container.read(nativeOnlineEnabledProvider.notifier).state = true;
    await tester.tap(find.byKey(const ValueKey('native-offline')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('start-offline-practice')),
      findsOneWidget,
    );
    expect(prefs.getString('offline_player_id_v1'), startsWith('LOCAL_'));
    online.complete();
    await tester.pump();
    expect(container.read(nativeOnlineEnabledProvider), isFalse);
    expect(
      find.byKey(const ValueKey('start-offline-practice')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful Online preparation activates only the current choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final online = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: NativePlayEntry(onOnline: () => online.future),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NativePlayEntry)),
        listen: false,
      );
      await tester.tap(find.byKey(const ValueKey('native-online')));
      await tester.pump();
      expect(container.read(nativeOnlineEnabledProvider), isFalse);
      online.complete();
      await tester.pump();
      expect(container.read(nativeOnlineEnabledProvider), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a stale Online failure cannot replace local play with an error',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final online = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: NativePlayEntry(onOnline: () => online.future),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('native-online')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('native-offline')));
      await tester.pumpAndSettle();
      online.completeError(StateError('offline'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('start-offline-practice')),
        findsOneWidget,
      );
      expect(find.text('online_entry_retry'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('local ambience is a cached WAV payload, not an internet URL', () {
    final music = DefaultAudioAssets.getMusic();
    expect(identical(music, DefaultAudioAssets.getMusic()), isTrue);
    final bytes = base64Decode(music.split(',').last);
    expect(ascii.decode(bytes.take(4).toList()), 'RIFF');
    expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
    expect(bytes.length, 44 + 4 * 22050 * 2);
  });
}
