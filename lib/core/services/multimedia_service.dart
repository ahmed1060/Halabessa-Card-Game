import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/global_settings_provider.dart';

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
        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.musicOverrideUrl;

        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          await _musicPlayer.play(UrlSource(overrideUrl));
        } else {
          await _musicPlayer.play(AssetSource(assetPath));
        }
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
        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.sfxOverrides[assetPath];

        if (overrideUrl != null && overrideUrl.isNotEmpty) {
           await _sfxPlayer.play(UrlSource(overrideUrl)).catchError((e) {
             debugPrint('MultimediaService: Remote SFX Playback error: $e');
           });
           return;
        }

        // On Web, audioplayers v6 AssetSource uses 'assets/' as default prefix.
        // If the path already has 'assets/', we clean it to avoid 'assets/assets/'.
        String effectivePath = assetPath;
        if (assetPath.startsWith('assets/')) {
           effectivePath = assetPath.replaceFirst('assets/', '');
        }
        
        // Use a local try-catch to avoid crashing the whole caller
        await _sfxPlayer.play(AssetSource(effectivePath)).catchError((e) {
          debugPrint('MultimediaService: SFX Playback error (caught): $e');
        });
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
