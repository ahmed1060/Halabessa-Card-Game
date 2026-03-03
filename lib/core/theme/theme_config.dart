import 'package:flutter/material.dart';

class ThemeConfig {
  static const Color primaryTeal = Color(0xFF00E5FF); // Electric Neon Teal
  static const Color accentPink = Color(0xFFFF4081);  // Vibrant Pink 
  static const Color goldAccent = Color(0xFFFFD600);  // Electric Gold
  static const Color darkBg = Color(0xFF0D1B2A);      // Deep Midnight
  static const Color surfaceGlass = Color(0x661B263B);
  
  // Legacy colors for compatibility
  static const Color darkGreen = Color(0xFF1B3022);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color darkTeal = Color(0xFF004D40);
  static const Color crimsonAccent = Color(0xFFB71C1C);

  static const String fontHeading = 'Righteous';
  static const String fontBody = 'Outfit';

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
        surface: const Color(0xFF1B263B), // Match surfaceGlass/AppBar color
        error: crimsonAccent,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontFamily: fontHeading, fontWeight: FontWeight.bold, color: Colors.white),
        headlineSmall: TextStyle(fontFamily: fontHeading, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
