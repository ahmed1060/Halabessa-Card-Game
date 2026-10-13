// Local design-review entry point. Never initialize cloud clients or create
// online accounts/rooms here. Production continues to use lib/main.dart.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/routes/app_routes.dart';
import 'package:halabessa/core/widgets/lantern_help_screen.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/bot_difficulty.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/presentation/pages/offline_practice_app.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';

class _PreviewAudio extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playMusic(String path, {bool loop = true}) async {}
  @override
  Future<void> playRoomMusic(String path, {bool loop = true}) async {}
  @override
  Future<void> playSfx(String path) async {}
  @override
  Future<void> vibrate() async {}
  @override
  void handleInteraction() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      ...offlinePlayOverrides(
        preferences,
        AppUser(uid: 'LOCAL_design_preview', email: '', displayName: 'You'),
        audioFactory: (_) => _PreviewAudio(),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        startLocale: const Locale('ar', 'EG'),
        fallbackLocale: const Locale('en', 'US'),
        saveLocale: false,
        path: 'assets/translations',
        child: Builder(
          builder: (context) => MaterialApp(
            title: 'Halabessa — Local UI Preview',
            debugShowCheckedModeBanner: false,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: ThemeData.dark(useMaterial3: true),
            home: const GameBoardScreen(),
            routes: {AppRoutes.help: (_) => const LanternHelpScreen()},
          ),
        ),
      ),
    ),
  );
  container
      .read(matchStateProvider.notifier)
      .startOfflinePracticeMatch(
        'LOCAL_design_preview',
        'You',
        difficulty: BotDifficulty.hard,
      );
}
