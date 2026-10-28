import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/age_eligibility_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/widgets/native_play_entry.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/lan/data/lan_connection.dart';
import 'package:halabessa/features/lan/presentation/lan_play_app.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import '../tool/lan_review_fixtures.dart';
import 'table_chat_ui_test.dart' show host;

void main() {
  testWidgets(
    'host board keeps the same replica across snapshots and blocks play during reconnect',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final room = ReviewLanHost();
      await host(
        tester,
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: LanPlayApp(
            unityEnabled: false,
            preferences: prefs,
            player: AppUser(uid: 'LOCAL_ui', email: '', displayName: 'Ahmed'),
            onExit: () {},
            hostFactory: (_, __) async => room,
            discoveryFactory: ReviewLanDiscovery.new,
            audioFactory: (_) => ReviewLanAudio(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('lan-create')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('lan-start')));
      await tester.tap(find.byKey(const ValueKey('lan-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameBoardScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameBoardScreen)),
        listen: false,
      );
      final original = container.read(matchStateProvider.notifier);
      room.local.publish({});
      await tester.pump();
      expect(container.read(matchStateProvider.notifier), same(original));
      room.local.status = 'reconnecting';
      room.local.publish({});
      await tester.pump();
      expect(find.text('lan_reconnecting'.tr()), findsOneWidget);
      expect(Firebase.apps, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manual address and identity fields build the same validated invitation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final room = ReviewLanHost();
      final invite = room.invitation(room.addresses.first);
      String? joined;
      await host(
        tester,
        LanPlayApp(
          unityEnabled: false,
          preferences: prefs,
          player: AppUser(uid: 'LOCAL_ui', email: '', displayName: 'Ahmed'),
          onExit: () {},
          discoveryFactory: ReviewLanDiscovery.new,
          joinFactory: (value, name) async {
            joined = value.text;
            return ReviewLanConnection();
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('lan-browse')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      for (final entry in {
        'address': invite.address,
        'port': '${invite.port}',
        'room': invite.room,
        'pin': invite.fingerprint,
        'secret': invite.secret,
      }.entries) {
        await tester.enterText(
          find.byKey(ValueKey('lan-${entry.key}')),
          entry.value,
        );
      }
      final join = find.widgetWithText(FilledButton, 'lan_join'.tr());
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(joined, invite.text);
      expect(find.text('lan_lobby'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    for (final size in [const Size(320, 568), const Size(850, 390)]) {
      testWidgets(
        'LAN entry, nearby/manual join and invitation lobby fit $locale $size',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final discovery = ReviewLanDiscovery();
          final room = ReviewLanHost();
          await host(
            tester,
            LanPlayApp(
              unityEnabled: false,
              preferences: preferences,
              player: AppUser(uid: 'LOCAL_ui', email: '', displayName: 'Ahmed'),
              onExit: () {},
              hostFactory: (_, __) async => room,
              discoveryFactory: () => discovery,
            ),
            locale: locale,
            size: size,
          );
          await tester.ensureVisible(find.byKey(const ValueKey('lan-browse')));
          await tester.tap(find.byKey(const ValueKey('lan-browse')));
          await tester.pumpAndSettle();
          expect(discovery.browsed, 1);
          expect(find.text('Halabessa Café'), findsOneWidget);
          expect(find.byType(TextField), findsNWidgets(2));
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('lan-create')));
          await tester.tap(find.byKey(const ValueKey('lan-create')));
          await tester.pumpAndSettle();
          expect(find.byType(QrImageView), findsOneWidget);
          expect(find.text('lan_lobby'.tr()).hitTestable(), findsOneWidget);
          await tester.ensureVisible(find.byKey(const ValueKey('lan-start')));
          expect(
            tester
                .widget<FilledButton>(find.byKey(const ValueKey('lan-start')))
                .onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
          expect(Firebase.apps, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets('a host created after backgrounding is immediately closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pending = Completer<LanHostedRoom>();
    final room = ReviewLanHost();
    await host(
      tester,
      LanPlayApp(
        preferences: preferences,
        player: AppUser(uid: 'LOCAL_ui', email: '', displayName: 'Ahmed'),
        onExit: () {},
        hostFactory: (_, __) => pending.future,
        discoveryFactory: ReviewLanDiscovery.new,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lan-create')));
    await tester.pump();
    for (final phase in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(phase);
    }
    await tester.pump();
    pending.complete(room);
    await tester.pumpAndSettle();
    expect(room.local.closeCount, 1);
    expect(find.byType(QrImageView), findsNothing);
    for (final phase in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(phase);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native LAN selection stays cloud-free and defeats a stale online completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AgeEligibilityNotifier.key: 'eligible',
      });
      final prefs = await SharedPreferences.getInstance(),
          online = Completer<void>();
      await host(
        tester,
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: NativePlayEntry(onOnline: () => online.future),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('native-online')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('native-lan')));
      await tester.tap(find.byKey(const ValueKey('native-lan')));
      await tester.pumpAndSettle();
      online.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LanPlayApp), findsOneWidget);
      expect(Firebase.apps, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
