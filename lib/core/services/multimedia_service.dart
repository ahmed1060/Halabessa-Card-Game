import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isMusicEnabled) {
        await _musicPlayer.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play music $assetPath: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (e) {
      debugPrint('MultimediaService: Failed to stop music: $e');
    }
  }

  // Audio - Sound Effects
  Future<void> playSfx(String assetPath) async {
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isSoundEnabled) {
        await _sfxPlayer.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play SFX $assetPath: $e');
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
