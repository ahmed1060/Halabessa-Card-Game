import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/lan/presentation/lan_play_app.dart';
import 'lan_review_fixtures.dart';
import 'package:halabessa/core/utils/web_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebUnityView();
  await EasyLocalization.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
        path: 'assets/translations',
        saveLocale: false,
        startLocale: Uri.base.queryParameters['lang'] == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en', 'US'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: ThemeConfig.darkTheme,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: LanPlayApp(
              unityEnabled: Uri.base.queryParameters['renderer'] == 'unity',
              preferences: preferences,
              player: AppUser(
                uid: 'LOCAL_review',
                email: '',
                displayName: 'Ahmed',
              ),
              onExit: () {},
              hostFactory: (driver, name) async =>
                  ReviewLanHost(driver: driver),
              joinFactory: (invite, name) async => ReviewLanConnection(),
              discoveryFactory: ReviewLanDiscovery.new,
              audioFactory: (_) => ReviewLanAudio(),
            ),
          ),
        ),
      ),
    ),
  );
}
