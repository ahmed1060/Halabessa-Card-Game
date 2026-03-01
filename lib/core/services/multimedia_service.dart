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

  // Web Autoplay Handling
  bool _hasInteracted = false;
  String? _pendingMusic;
  final Map<String, bool> _pendingSfx = {};

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
        if (_currentMusicPath == assetPath && _hasInteracted) return;

        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.musicOverrideUrl;

        Source source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            final base64Data = overrideUrl.split(',').last;
            source = BytesSource(base64Decode(base64Data));
          } else {
            source = UrlSource(overrideUrl);
          }
        } else {
          source = AssetSource(assetPath);
        }

        await _musicPlayer.play(source).then((_) {
          _hasInteracted = true;
          _currentMusicPath = assetPath;
          _pendingMusic = null;
        }).catchError((e) {
          if (e.toString().contains('NotAllowedError')) {
            debugPrint('MultimediaService: Autoplay blocked. Queueing music.');
            _pendingMusic = assetPath;
          } else {
            debugPrint('MultimediaService: Music Playback error: $e');
          }
        });
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
        final overrideUrl = globalSettings.sfxOverrides[assetPath];

        Source source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            final base64Data = overrideUrl.split(',').last;
            source = BytesSource(base64Decode(base64Data));
          } else {
            source = UrlSource(overrideUrl);
          }
        } else {
          source = AssetSource(assetPath);
        }

        await _sfxPlayer.play(source).then((_) {
          // If we successfully played an SFX, we have user interaction!
          if (!_hasInteracted) {
             _hasInteracted = true;
             if (_pendingMusic != null) {
               playMusic(_pendingMusic!);
             }
          }
        }).catchError((e) {
          if (e.toString().contains('NotAllowedError')) {
            debugPrint('MultimediaService: Autoplay blocked for SFX.');
          } else {
            debugPrint('MultimediaService: SFX Playback error: $e');
          }
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
