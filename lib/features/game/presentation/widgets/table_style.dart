import 'package:flutter/material.dart';

/// Table-only tokens; migrate supporting screens without changing equipped skins.
abstract final class TableStyle {
  static const felt = Color(0xFF123E35);
  static const ink = Color(0xFF102923);
  static const ivory = Color(0xFFF7F3E8);
  static const brass = Color(0xFFC5A567);
  static const muted = Color(0xFFA9BBB2);
  static const red = Color(0xFFB73B42);
  static const label = TextStyle(fontFamily: '', color: ivory, fontSize: 14, height: 1.25);
  static const detail = TextStyle(fontFamily: '', color: muted, fontSize: 12, height: 1.25);
}
