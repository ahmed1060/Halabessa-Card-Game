import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/theme_config.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/multimedia_service.dart';
import 'core/services/player_presence.dart';
import 'core/providers/age_eligibility_provider.dart';
import 'core/widgets/age_eligibility_screen.dart';
import 'core/widgets/app_orientation_scope.dart';
import 'core/widgets/web_orientation_gate.dart';
import 'core/providers/native_play_provider.dart';
import 'core/widgets/native_play_entry.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'core/utils/web_registry.dart';
import 'features/game/presentation/widgets/unity_persistent_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebUnityView();
  await EasyLocalization.ensureInitialized();

  // Mobile Immersion & Orientation
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final sharedPrefs = await SharedPreferences.getInstance();
  await applyAppOrientation(
    sharedPrefs.getString('gameOrientation') == 'portrait'
        ? GameOrientation.portrait
        : GameOrientation.landscape,
  );

  if (!isNativeMobile)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint("Firebase init failed (likely missing config): $e");
    }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('ar', 'EG'),
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: const AppOrientationScope(child: HalabessaApp()),
      ),
    ),
  );
}

class HalabessaApp extends ConsumerWidget {
  const HalabessaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Gate every route (including deep links) before reading the auth stream or
    // mounting provider buttons, account screens, presence or the Unity overlay.
    if (ref.watch(ageEligibilityProvider) != AgeEligibility.eligible) {
      return MaterialApp(
        key: const ValueKey('age-gate'),
        title: 'Halabessa',
        initialRoute: '/',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeConfig.lightTheme,
        darkTheme: ThemeConfig.darkTheme,
        themeMode: settings.themeMode,
        debugShowCheckedModeBanner: false,
        home: const AgeEligibilityScreen(),
      );
    }
    if (isNativeMobile && !ref.watch(nativeOnlineEnabledProvider)) {
      return MaterialApp(
        key: const ValueKey('native-local-entry'),
        title: 'Halabessa',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeConfig.lightTheme,
        darkTheme: ThemeConfig.darkTheme,
        themeMode: settings.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                settings.reducedMotion ||
                MediaQuery.disableAnimationsOf(context),
          ),
          child: WebOrientationGate(
            child: ColoredBox(
              color: ThemeConfig.darkBg,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: NativePlayEntry(
          onOnline: () async {
            if (Firebase.apps.isEmpty) {
              await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              ).timeout(const Duration(seconds: 15));
            }
          },
        ),
      );
    }
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;

    return MaterialApp(
      key: const ValueKey('game-app'),
      title: 'Halabessa',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: settings.themeMode,
      initialRoute: AppRoutes.initial,
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                settings.reducedMotion ||
                MediaQuery.disableAnimationsOf(context),
          ),
          child: WebOrientationGate(
            child: ColoredBox(
              color: ThemeConfig.darkBg,
              child: Stack(
                children: [
                  const UnityPersistentOverlay(), // Move to background
                  if (child != null)
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => ref
                          .read(multimediaServiceProvider)
                          .handleInteraction(),
                      child: uid == null
                          ? child
                          : PlayerPresenceSession(
                              key: ValueKey(uid),
                              uid: uid,
                              child: child,
                            ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
