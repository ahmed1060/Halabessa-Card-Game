import 'package:flutter/material.dart';

class ThemeConfig {
  static const Color primaryTeal = Color(0xFF78D2AF); // Lantern mint
  static const Color accentPink = Color(0xFFED767A); // Rival rose
  static const Color goldAccent = Color(0xFFFFC65B); // Lantern amber
  static const Color darkBg = Color(0xFF3B274C); // Cafe aubergine
  static const Color surfaceGlass = Color(0xE6192638);
  
  // Legacy colors for compatibility
  static const Color darkGreen = Color(0xFF1B3022);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color darkTeal = Color(0xFF004D40);
  static const Color crimsonAccent = Color(0xFFB71C1C);
  static const Color boardGreen = Color(0xFF1B3022);
  static const Color cardDarkBg = Color(0xFF1B263B);

  // These aliases are bundled fonts, not system fallbacks. Cairo covers Arabic.
  static const String fontHeading = 'LanternText';
  static const String fontBody = 'LanternText';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontBody,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: goldAccent,
        error: crimsonAccent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontFamily: fontHeading, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(fontFamily: fontHeading),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontBody,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
        primary: primaryTeal,
        secondary: goldAccent,
        surface: const Color(0xFF192638),
        error: crimsonAccent,
      ),
      scaffoldBackgroundColor: darkBg,
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: goldAccent, foregroundColor: const Color(0xFF192638),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFF6E7), backgroundColor: const Color(0xFF192638),
        minimumSize: const Size(48, 48), side: const BorderSide(color: primaryTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      )),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontFamily: fontHeading, fontWeight: FontWeight.bold, color: Colors.white),
        headlineSmall: TextStyle(fontFamily: fontHeading, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF192638),
        foregroundColor: Color(0xFFFFF6E7),
        elevation: 0,
      ),
    );
  }
}
