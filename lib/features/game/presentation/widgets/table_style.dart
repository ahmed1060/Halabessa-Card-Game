import 'package:flutter/material.dart';

/// Table-only tokens; migrate supporting screens without changing equipped skins.
abstract final class TableStyle {
  static const felt = Color(0xFF3B274C);
  static const ink = Color(0xFF192638);
  static const ivory = Color(0xFFFFF6E7);
  static const brass = Color(0xFFFFC65B);
  static const muted = Color(0xFFCCC3D4);
  static const red = Color(0xFFED767A);
  static const mint = Color(0xFF78D2AF);
  static const label = TextStyle(fontFamily: 'LanternText', fontFamilyFallback: ['LanternArabic'], color: ivory, fontSize: 14, height: 1.25);
  static const detail = TextStyle(fontFamily: 'LanternText', fontFamilyFallback: ['LanternArabic'], color: muted, fontSize: 12, height: 1.25);
}
