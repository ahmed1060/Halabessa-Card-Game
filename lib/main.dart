import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/theme_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Try to initialize Firebase, but catch errors if it's not configured yet
  // We will configure Firebase properly later.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed (likely missing config): \$e");
  }

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('ar', 'EG'), Locale('ar', 'SA'), Locale('en', 'US')],
        path: 'assets/translations', 
        fallbackLocale: const Locale('en', 'US'),
        child: const HalabessaApp(),
      ),
    ),
  );
}

class HalabessaApp extends StatelessWidget {
  const HalabessaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7alabessa',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.initial,
      routes: AppRoutes.routes,
    );
  }
}