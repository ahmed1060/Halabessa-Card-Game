import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class MultimediaService {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final Ref _ref;

  MultimediaService(this._ref) {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  // Haptics
  Future<void> vibrate() async {
    final settings = _ref.read(settingsProvider);
    if (settings.isHapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  // Audio - Background Music
  Future<void> playMusic(String assetPath) async {
    final settings = _ref.read(settingsProvider);
    if (settings.isMusicEnabled) {
      await _musicPlayer.play(AssetSource(assetPath));
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  // Audio - Sound Effects
  Future<void> playSfx(String assetPath) async {
    final settings = _ref.read(settingsProvider);
    if (settings.isSoundEnabled) {
      // Create new player for overlapping sounds if needed, 
      // but for simple card game, one SFX player is usually enough 
      // or we can use dedicated players for specific events.
      await _sfxPlayer.play(AssetSource(assetPath));
    }
  }

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

final multimediaServiceProvider = Provider<MultimediaService>((ref) {
  final service = MultimediaService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
