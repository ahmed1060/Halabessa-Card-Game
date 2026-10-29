// Local, memory-only review target. Never initializes Firebase or writes a DOB.
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/lantern_page_frame.dart';
import 'package:halabessa/features/auth/data/repositories/birth_date_store.dart';
import 'package:halabessa/features/auth/domain/repositories/auth_repository.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/presentation/providers/birth_date_providers.dart';
import 'package:halabessa/features/auth/presentation/widgets/profile_birth_date.dart';

class _MemoryDates implements BirthDateStore {
  DateTime? date;
  final changes = StreamController<DateTime?>.broadcast();
  @override
  Stream<DateTime?> watch(String uid) async* {
    yield date;
    yield* changes.stream;
  }

  @override
  Future<void> save(String uid, DateTime value) async {
    date = birthDateOnly(value);
    changes.add(date);
  }
}

class _LocalAuth implements AuthRepository {
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Cloud operations are disabled in this local review');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final dates = _MemoryDates();
  final locale = Uri.base.queryParameters['lang'] == 'ar'
      ? const Locale('ar', 'EG')
      : const Locale('en', 'US');
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionUidProvider.overrideWith((ref) => 'LOCAL_REVIEW_ONLY'),
        birthDateStoreProvider.overrideWithValue(dates),
        authRepositoryProvider.overrideWithValue(_LocalAuth()),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
        path: 'assets/translations',
        startLocale: locale,
        saveLocale: false,
        child: const _ReviewApp(),
      ),
    ),
  );
}

class _ReviewApp extends StatelessWidget {
  const _ReviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeConfig.darkTheme,
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    routes: {
      '/account/delete': (_) => const Scaffold(
        body: Center(
          child: Text('Local review: no account or cloud data exists.'),
        ),
      ),
    },
    home: const AccountBirthDateGate(
      child: LanternPageFrame(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SizedBox(
                width: 440,
                child: Card(child: ProfileBirthDateTile()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
