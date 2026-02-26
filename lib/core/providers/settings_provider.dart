import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool isSoundEnabled;
  final bool isMusicEnabled;
  final bool isHapticsEnabled;
  final String languageCode;
  final ThemeMode themeMode;

  SettingsState({
    this.isSoundEnabled = true,
    this.isMusicEnabled = true,
    this.isHapticsEnabled = true,
    this.languageCode = 'en',
    this.themeMode = ThemeMode.system,
  });

  SettingsState copyWith({
    bool? isSoundEnabled,
    bool? isMusicEnabled,
    bool? isHapticsEnabled,
    String? languageCode,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isMusicEnabled: isMusicEnabled ?? this.isMusicEnabled,
      isHapticsEnabled: isHapticsEnabled ?? this.isHapticsEnabled,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SettingsState(
      isSoundEnabled: _prefs.getBool('isSoundEnabled') ?? true,
      isMusicEnabled: _prefs.getBool('isMusicEnabled') ?? true,
      isHapticsEnabled: _prefs.getBool('isHapticsEnabled') ?? true,
      languageCode: _prefs.getString('languageCode') ?? 'en',
      themeMode: ThemeMode.values[_prefs.getInt('themeMode') ?? 0],
    );
  }

  Future<void> toggleSound(bool value) async {
    state = state.copyWith(isSoundEnabled: value);
    await _prefs.setBool('isSoundEnabled', value);
  }

  Future<void> toggleMusic(bool value) async {
    state = state.copyWith(isMusicEnabled: value);
    await _prefs.setBool('isMusicEnabled', value);
  }

  Future<void> toggleHaptics(bool value) async {
    state = state.copyWith(isHapticsEnabled: value);
    await _prefs.setBool('isHapticsEnabled', value);
  }

  Future<void> setLanguage(String langCode) async {
    state = state.copyWith(languageCode: langCode);
    await _prefs.setString('languageCode', langCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt('themeMode', mode.index);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Should be overridden in ProviderScope
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
