import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: goldAccent,
        error: crimsonAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        headlineMedium: GoogleFonts.righteous(fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.righteous(),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.dark,
        primary: primaryTeal,
        secondary: goldAccent,
        surface: darkTeal,
        error: crimsonAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineMedium: GoogleFonts.righteous(fontWeight: FontWeight.bold, color: Colors.white),
        headlineSmall: GoogleFonts.righteous(color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
