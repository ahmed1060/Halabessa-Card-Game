import 'dart:convert';
import 'dart:typed_data';
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
  String? _currentMusicPath;

  Future<void> playMusic(String assetPath) async {
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isMusicEnabled) {
        if (_currentMusicPath == assetPath) return; // Already playing

        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.musicOverrideUrl;

        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            final base64Data = overrideUrl.split(',').last;
            final bytes = base64Decode(base64Data);
            await _musicPlayer.play(BytesSource(bytes));
          } else {
            await _musicPlayer.play(UrlSource(overrideUrl));
          }
        } else {
          await _musicPlayer.play(AssetSource(assetPath));
        }
        _currentMusicPath = assetPath;
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play music $assetPath: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _currentMusicPath = null;
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
        
        // Lookup using the "clean" path (e.g. 'sfx/capture.mp3')
        final overrideUrl = globalSettings.sfxOverrides[assetPath];

        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            final base64Data = overrideUrl.split(',').last;
            final bytes = base64Decode(base64Data);
            await _sfxPlayer.play(BytesSource(bytes)).catchError((e) {
              debugPrint('MultimediaService: Base64 SFX Playback error: $e');
            });
          } else {
            await _sfxPlayer.play(UrlSource(overrideUrl)).catchError((e) {
              debugPrint('MultimediaService: Remote SFX Playback error: $e');
            });
          }
          return;
        }

        // Use the path directly as AssetSource (caller provides clean path)
        await _sfxPlayer.play(AssetSource(assetPath)).catchError((e) {
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
