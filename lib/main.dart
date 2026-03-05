import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/theme_config.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/multimedia_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Mobile Immersion & Orientation
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final sharedPrefs = await SharedPreferences.getInstance();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed (likely missing config): $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar', 'SA'), Locale('en', 'US')],
        path: 'assets/translations', 
        fallbackLocale: const Locale('en', 'US'),
        child: const HalabessaApp(),
      ),
    ),
  );
}

class HalabessaApp extends ConsumerWidget {
  const HalabessaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: '7alabessa',
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
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => ref.read(multimediaServiceProvider).handleInteraction(),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
