import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:halabessa/core/providers/native_play_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/data/repositories/birth_date_store.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/birth_date_providers.dart';
import 'package:halabessa/features/auth/presentation/widgets/profile_birth_date.dart';
import 'table_chat_ui_test.dart' show host;

class _Dates implements BirthDateStore {
  final dates = <String, DateTime?>{};
  final watched = <String>[];
  final saved = <String>[];
  final events = <String, StreamController<DateTime?>>{};
  @override
  Stream<DateTime?> watch(String uid) async* {
    watched.add(uid);
    yield dates[uid];
    yield* events.putIfAbsent(uid, () => StreamController.broadcast()).stream;
  }

  void publish(String uid, DateTime date) {
    dates[uid] = date;
    events[uid]?.add(date);
  }

  @override
  Future<void> save(String uid, DateTime date) async {
    saved.add(uid);
    publish(uid, birthDateOnly(date));
  }
}

final _uid = StateProvider<String?>((ref) => 'registered');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test(
    'private timestamps round trip as dates; the exact thirteenth birthday counts',
    () {
      final leap = DateTime.utc(2000, 2, 29);
      expect(parseProfileBirthDate(Timestamp.fromDate(leap)), leap);
      expect(parseProfileBirthDate(null), isNull);
      expect(() => parseProfileBirthDate('2000-02-29'), throwsStateError);
      expect(
        validProfileBirthDate(
          DateTime.utc(2013, 10, 26),
          DateTime.utc(2026, 10, 26),
        ),
        isTrue,
      );
      expect(
        validProfileBirthDate(
          DateTime.utc(2013, 10, 27),
          DateTime.utc(2026, 10, 26),
        ),
        isFalse,
      );
      expect(
        validProfileBirthDate(DateTime.utc(1899), DateTime.utc(2026)),
        isFalse,
      );
      expect(
        validProfileBirthDate(
          DateTime.utc(2012, 2, 29),
          DateTime.utc(2025, 2, 28),
        ),
        isFalse,
      );
      expect(
        validProfileBirthDate(
          DateTime.utc(2012, 2, 29),
          DateTime.utc(2025, 3, 1),
        ),
        isTrue,
      );
    },
  );

  test('a new account never inherits another account birthday', () async {
    final store = _Dates()..dates['registered'] = DateTime.utc(2000);
    final container = ProviderContainer(
      overrides: [
        sessionUidProvider.overrideWith((ref) => ref.watch(_uid)),
        birthDateStoreProvider.overrideWithValue(store),
      ],
    );
    final subscription = container.listen(profileBirthDateProvider, (_, __) {});
    expect(
      await container.read(profileBirthDateProvider.future),
      DateTime.utc(2000),
    );
    container.read(_uid.notifier).state = 'guest';
    expect(await container.read(profileBirthDateProvider.future), isNull);
    store.publish('registered', DateTime.utc(1995));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(profileBirthDateProvider).asData?.value, isNull);
    await container.read(saveProfileBirthDateProvider)(DateTime.utc(2001));
    expect(store.saved, ['guest']);
    subscription.close();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'offline and signed-out paths never construct a cloud birthday store',
    () async {
      for (final offline in [false, true]) {
        final container = ProviderContainer(
          overrides: [
            offlineSessionProvider.overrideWithValue(offline),
            sessionUidProvider.overrideWithValue(
              offline ? 'LOCAL_player' : null,
            ),
            birthDateStoreProvider.overrideWith(
              (ref) => throw StateError('cloud forbidden'),
            ),
          ],
        );
        final subscription = container.listen(
          profileBirthDateProvider,
          (_, __) {},
        );
        expect(await container.read(profileBirthDateProvider.future), isNull);
        await expectLater(
          container.read(saveProfileBirthDateProvider)(DateTime.utc(2000)),
          throwsStateError,
        );
        subscription.close();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      }
    },
  );

  for (final uid in ['guest', 'registered']) {
    testWidgets(
      '$uid must complete a missing birthday before protected content appears',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final store = _Dates();
        await host(
          tester,
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              sessionUidProvider.overrideWithValue(uid),
              birthDateStoreProvider.overrideWithValue(store),
            ],
            child: const AccountBirthDateGate(child: Text('Protected game')),
          ),
        );
        expect(find.byType(BirthDateForm), findsOneWidget);
        expect(find.text('Protected game'), findsNothing);
        expect(find.text('Delete account'), findsOneWidget);
        store.publish(uid, DateTime.utc(2000));
        await tester.pumpAndSettle();
        expect(find.text('Protected game'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets('birthday load failure never exposes protected content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await host(
      tester,
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          sessionUidProvider.overrideWithValue('owner'),
          profileBirthDateProvider.overrideWith(
            (ref) => Stream.error(StateError('unavailable')),
          ),
        ],
        child: const AccountBirthDateGate(child: Text('Protected game')),
      ),
    );
    expect(find.text('Protected game'), findsNothing);
    expect(find.text('Retry loading your birth date'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('log_out'.tr()), findsOneWidget);
  });

  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets('date form is usable in a narrow viewport $locale', (
      tester,
    ) async {
      final saved = <DateTime>[];
      await host(
        tester,
        SingleChildScrollView(
          child: BirthDateForm(
            onboarding: true,
            pickDate: (_, __) async => DateTime(2000, 2, 29, 13, 5),
            onSave: (date) async => saved.add(date),
          ),
        ),
        locale: locale,
        size: const Size(320, 568),
      );
      final button = find.byKey(const ValueKey('profile-birth-date-save'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('profile-birth-date-picker')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(saved, [DateTime.utc(2000, 2, 29)]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'save failure is retryable and a held save cannot double-submit',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await host(
        tester,
        SingleChildScrollView(
          child: BirthDateForm(
            initialDate: DateTime.utc(2000),
            onSave: (_) async {
              calls++;
              if (calls == 1) await pending.future;
            },
          ),
        ),
      );
      final button = find.byKey(const ValueKey('profile-birth-date-save'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      pending.completeError(StateError('save failed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your birth date. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  testWidgets('underage input never reaches the account save', (tester) async {
    var blocked = false;
    await host(
      tester,
      SingleChildScrollView(
        child: BirthDateForm(
          initialDate: DateTime.utc(DateTime.now().year - 10),
          onUnderage: (_) async => blocked = true,
          onSave: (_) async => fail('underage date was saved'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-birth-date-save')));
    await tester.pumpAndSettle();
    expect(blocked, isTrue);
  });
}
