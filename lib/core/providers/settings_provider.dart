import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool isSoundEnabled;
  final bool isMusicEnabled;
  final bool isHapticsEnabled;
  final bool is3DModeEnabled;
  final double musicVolume;
  final double soundVolume;
  final String languageCode;
  final ThemeMode themeMode;

  SettingsState({
    this.isSoundEnabled = true,
    this.isMusicEnabled = true,
    this.isHapticsEnabled = true,
    this.is3DModeEnabled = true,
    this.musicVolume = 1.0,
    this.soundVolume = 1.0,
    this.languageCode = 'en',
    this.themeMode = ThemeMode.system,
  });

  SettingsState copyWith({
    bool? isSoundEnabled,
    bool? isMusicEnabled,
    bool? isHapticsEnabled,
    bool? is3DModeEnabled,
    double? musicVolume,
    double? soundVolume,
    String? languageCode,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isMusicEnabled: isMusicEnabled ?? this.isMusicEnabled,
      isHapticsEnabled: isHapticsEnabled ?? this.isHapticsEnabled,
      is3DModeEnabled: is3DModeEnabled ?? this.is3DModeEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      soundVolume: soundVolume ?? this.soundVolume,
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
      is3DModeEnabled: _prefs.getBool('is3DModeEnabled') ?? true,
      musicVolume: _prefs.getDouble('musicVolume') ?? 1.0,
      soundVolume: _prefs.getDouble('soundVolume') ?? 1.0,
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

  Future<void> setMusicVolume(double value) async {
    state = state.copyWith(musicVolume: value);
    await _prefs.setDouble('musicVolume', value);
  }

  Future<void> setSoundVolume(double value) async {
    state = state.copyWith(soundVolume: value);
    await _prefs.setDouble('soundVolume', value);
  }

  Future<void> toggleHaptics(bool value) async {
    state = state.copyWith(isHapticsEnabled: value);
    await _prefs.setBool('isHapticsEnabled', value);
  }

  Future<void> toggle3DMode(bool value) async {
    state = state.copyWith(is3DModeEnabled: value);
    await _prefs.setBool('is3DModeEnabled', value);
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
