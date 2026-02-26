import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  static const Color primaryGreen = Color(0xFF1B4332); // Deep Cinematic Forest Green
  static const Color darkGreen = Color(0xFF081C15);    // Opulent Dark Green (near black)
  static const Color accentGreen = Color(0xFF40916C);  // Vibrant Felt Green
  static const Color goldAccent = Color(0xFFD4AF37);  // Classic Gold
  static const Color surfaceGlass = Color(0x33000000); // Semi-transparent black for glassmorphism

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
      fontFamilyFallback: [
        GoogleFonts.notoSansArabic().fontFamily!,
        'sans-serif',
      ],
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
      fontFamilyFallback: [
        GoogleFonts.notoSansArabic().fontFamily!,
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
