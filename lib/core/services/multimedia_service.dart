import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/global_settings_provider.dart';

class MultimediaService extends ChangeNotifier {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final Ref _ref;

  MultimediaService(this._ref) {
    // Notify listeners when state changes so UI can update icons
    _musicPlayer.onPlayerStateChanged.listen((_) => notifyListeners());
    _sfxPlayer.onPlayerStateChanged.listen((_) => notifyListeners());
  }

  // Web Autoplay Handling
  bool _hasInteracted = false;
  String? _pendingMusic;

  void handleInteraction() {
    if (!_hasInteracted) {
      debugPrint('MultimediaService: Interaction detected. Rescuing audio...');
      _hasInteracted = true;
      if (_pendingMusic != null) {
        playMusic(_pendingMusic!);
      }
      notifyListeners();
    }
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
  String? get currentMusicPath => _currentMusicPath;
  PlayerState get musicState => _musicPlayer.state;
  PlayerState get sfxState => _sfxPlayer.state;

  Stream<PlayerState> get musicStateStream => _musicPlayer.onPlayerStateChanged;
  Stream<PlayerState> get sfxStateStream => _sfxPlayer.onPlayerStateChanged;

  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isMusicEnabled) {
        if (_currentMusicPath == assetPath && _hasInteracted) return;

        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.musicOverrideUrl;

        Source? source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            // On Web, passing the Data URL directly is more stable than BytesSource
            source = UrlSource(overrideUrl);
          } else {
            source = UrlSource(overrideUrl);
          }
        } else {
          // Skip if no asset exists (avoiding Code 4 errors in empty projects)
          debugPrint('MultimediaService: No override found for $assetPath and folder is empty. Skipping.');
          return;
        }

        if (source != null) {
          await _musicPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
          await _musicPlayer.play(source).then((_) {
            _hasInteracted = true;
            _currentMusicPath = assetPath;
            _pendingMusic = null;
            notifyListeners();
          }).catchError((e) {
            if (e.toString().contains('NotAllowedError')) {
              debugPrint('MultimediaService: Autoplay blocked. Queueing music.');
              _pendingMusic = assetPath;
            } else {
              debugPrint('MultimediaService: Music Playback error: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play music $assetPath: $e');
    }
  }

  Future<void> playRoomMusic(String assetPath, {bool loop = true}) async {
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isMusicEnabled) {
        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.roomMusicOverrideUrl;

        Source? source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          source = UrlSource(overrideUrl);
        } else {
          debugPrint('MultimediaService: No room music override found. Skipping.');
          return;
        }

        if (source != null) {
          await _musicPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
          await _musicPlayer.play(source).then((_) {
            _hasInteracted = true;
            _currentMusicPath = assetPath;
            _pendingMusic = null;
            notifyListeners();
          }).catchError((e) {
            if (e.toString().contains('NotAllowedError')) {
              _pendingMusic = assetPath;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play room music: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _currentMusicPath = null;
      notifyListeners();
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

        Source? source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          if (overrideUrl.startsWith('data:')) {
            source = UrlSource(overrideUrl);
          } else {
            source = UrlSource(overrideUrl);
          }
        } else {
          // Only play AssetSource if we are SURE it's not one of the missing ones
          // Since the user said there are NO original sounds, we skip.
          return;
        }

        if (source != null) {
          await _sfxPlayer.play(source).then((_) {
            handleInteraction(); // Success! Mark interaction and rescue music
          }).catchError((e) {
            if (e.toString().contains('NotAllowedError')) {
              debugPrint('MultimediaService: Autoplay blocked for SFX.');
            } else {
              debugPrint('MultimediaService: SFX Playback error: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('MultimediaService: Failed to play SFX $assetPath: $e');
    }
  }

  Future<void> stopSfx() async {
    try {
      await _sfxPlayer.stop();
    } catch (e) {
      debugPrint('MultimediaService: Failed to stop SFX: $e');
    }
  }

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

final multimediaServiceProvider = ChangeNotifierProvider<MultimediaService>((ref) {
  final service = MultimediaService(ref);
  return service;
});
