import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color darkGreen = Color(0xFF0D3310);
  static const Color goldAccent = Color(0xFFFFD700);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: goldAccent,
      ),
      textTheme: GoogleFonts.cairoTextTheme(),
      fontFamily: GoogleFonts.cairo().fontFamily,
      fontFamilyFallback: const ['sans-serif', 'Arial'],
      appBarTheme: const AppBarTheme(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.dark,
        primary: primaryGreen,
        secondary: goldAccent,
        surface: darkGreen,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      fontFamily: GoogleFonts.cairo().fontFamily,
      fontFamilyFallback: const ['sans-serif', 'Arial'],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
