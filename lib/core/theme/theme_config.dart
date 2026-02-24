import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    return baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
    );
    return baseTheme.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(baseTheme.textTheme),
    );
  }
}
