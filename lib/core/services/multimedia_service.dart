import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/global_settings_provider.dart';
import 'default_audio_assets.dart';
import '../providers/native_play_provider.dart';

class MultimediaService extends ChangeNotifier {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final Ref _ref;

  MultimediaService(this._ref) {
    // Notify listeners when state changes so UI can update icons
    _musicPlayer.onPlayerStateChanged.listen((_) => notifyListeners());
    _sfxPlayer.onPlayerStateChanged.listen((_) => notifyListeners());

    // Auto-rescue music when global settings overrides are loaded
    _ref.listen(globalSettingsProvider, (previous, next) {
      if (_pendingMusic != null && next.musicOverrideUrl != null) {
        debugPrint(
          'MultimediaService: Global settings loaded. Rescuing pending music: $_pendingMusic',
        );
        final musicToRescue = _pendingMusic!;
        _pendingMusic = null;
        playMusic(musicToRescue);
      }
    });

    // Stop music immediately if disabled in settings, or update volume
    _ref.listen(settingsProvider, (previous, next) {
      if (previous?.isMusicEnabled == true && next.isMusicEnabled == false) {
        stopMusic();
      } else if (previous?.isMusicEnabled == false &&
          next.isMusicEnabled == true) {
        if (_currentMusicPath != null) {
          playMusic(_currentMusicPath!);
        }
      } else if (previous?.musicVolume != next.musicVolume) {
        _musicPlayer.setVolume(next.musicVolume);
      }

      if (previous?.soundVolume != next.soundVolume) {
        _sfxPlayer.setVolume(next.soundVolume);
      }
    });
  }

  // Web Autoplay Handling
  bool _hasInteracted = false;
  String? _pendingMusic;

  void handleInteraction() {
    if (!_hasInteracted) {
      debugPrint('MultimediaService: Interaction detected. Rescuing audio...');
      _hasInteracted = true;
      final musicToRescue = _pendingMusic;
      if (musicToRescue != null) {
        _pendingMusic = null;
        playMusic(musicToRescue);
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
  String? _lastPlayedUrl;
  String? get currentMusicPath => _currentMusicPath;
  PlayerState get musicState => _musicPlayer.state;
  PlayerState get sfxState => _sfxPlayer.state;

  Stream<PlayerState> get musicStateStream => _musicPlayer.onPlayerStateChanged;
  Stream<PlayerState> get sfxStateStream => _sfxPlayer.onPlayerStateChanged;

  Source _localSource(String dataUri) => kIsWeb
      ? UrlSource(dataUri)
      : BytesSource(
          base64Decode(dataUri.substring(dataUri.indexOf(',') + 1)),
          mimeType: 'audio/wav',
        );

  Future<void> _playLocalMusic(String assetPath, bool loop) async {
    try {
      _currentMusicPath = assetPath;
      final settings = _ref.read(settingsProvider);
      if (!settings.isMusicEnabled) return;
      if (!_hasInteracted) {
        _pendingMusic = assetPath;
        return;
      }
      if (_musicPlayer.state == PlayerState.playing &&
          _lastPlayedUrl == 'local:$assetPath') {
        await _musicPlayer.setVolume(settings.musicVolume);
        return;
      }
      _lastPlayedUrl = 'local:$assetPath';
      await _musicPlayer.setVolume(settings.musicVolume);
      await _musicPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await _musicPlayer.play(_localSource(DefaultAudioAssets.getMusic()));
      _pendingMusic = null;
    } catch (error) {
      if (kDebugMode) debugPrint('Local music unavailable: $error');
    }
  }

  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    if (_ref.read(offlineSessionProvider))
      return _playLocalMusic(assetPath, loop);
    try {
      _currentMusicPath = assetPath;
      final settings = _ref.read(settingsProvider);

      if (!settings.isMusicEnabled) return;

      if (!_hasInteracted) {
        debugPrint(
          'MultimediaService: Autoplay blocked. Queueing music: $assetPath',
        );
        _pendingMusic = assetPath;
        return;
      }

      final globalSettings = _ref.read(globalSettingsProvider);
      final overrideUrl = globalSettings.musicOverrideUrl;

      if (overrideUrl == null || overrideUrl.isEmpty) {
        debugPrint(
          'MultimediaService: No override URL for $assetPath. Queueing.',
        );
        _pendingMusic = assetPath;
        return;
      }

      // Force restart if different URL even if playing
      if (_musicPlayer.state == PlayerState.playing &&
          _lastPlayedUrl == overrideUrl) {
        await _musicPlayer.setVolume(
          settings.musicVolume,
        ); // Still update volume
        return;
      }

      debugPrint('MultimediaService: Playing music from $overrideUrl');
      _lastPlayedUrl = overrideUrl;
      await _musicPlayer.setVolume(settings.musicVolume);
      await _musicPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await _musicPlayer
          .play(UrlSource(overrideUrl))
          .then((_) {
            _pendingMusic = null;
            notifyListeners();
          })
          .catchError((e) {
            if (e.toString().contains('NotAllowedError')) {
              _pendingMusic = assetPath;
            } else {
              debugPrint('MultimediaService: Music Playback error: $e');
            }
          });
    } catch (e) {
      debugPrint('MultimediaService: Failed to play music $assetPath: $e');
    }
  }

  Future<void> playRoomMusic(String assetPath, {bool loop = true}) async {
    if (_ref.read(offlineSessionProvider))
      return _playLocalMusic(assetPath, loop);
    try {
      _currentMusicPath = assetPath;
      final settings = _ref.read(settingsProvider);
      if (!settings.isMusicEnabled) return;

      if (!_hasInteracted) {
        _pendingMusic = assetPath;
        return;
      }

      final globalSettings = _ref.read(globalSettingsProvider);
      final overrideUrl = globalSettings.roomMusicOverrideUrl;

      if (overrideUrl == null || overrideUrl.isEmpty) {
        _pendingMusic = assetPath;
        return;
      }

      // Force restart if different URL even if playing
      if (_musicPlayer.state == PlayerState.playing &&
          _lastPlayedUrl == overrideUrl) {
        return;
      }

      _lastPlayedUrl = overrideUrl;
      await _musicPlayer.setVolume(settings.musicVolume);
      await _musicPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await _musicPlayer
          .play(UrlSource(overrideUrl))
          .then((_) {
            _pendingMusic = null;
            notifyListeners();
          })
          .catchError((e) {
            if (e.toString().contains('NotAllowedError')) {
              _pendingMusic = assetPath;
            }
          });
    } catch (e) {
      debugPrint('MultimediaService: Failed to play room music: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _pendingMusic = null; // Clear pending on manual stop
      _lastPlayedUrl = null;
      notifyListeners();
    } catch (e) {
      debugPrint('MultimediaService: Failed to stop music: $e');
    }
  }

  // Existing domain callers stay unchanged. A mounted presentation scope owns
  // only card contact sounds; every other sound/music path remains pass-through.
  Object? _cardAudioOwner;
  void Function() ownCardPresentationAudio(Object owner) {
    _cardAudioOwner = owner;
    return () {
      if (identical(_cardAudioOwner, owner)) _cardAudioOwner = null;
    };
  }

  Future<void> playSfx(String assetPath) => _playSfx(assetPath);
  Future<void> playPresentationSfx(String assetPath) =>
      _playSfx(assetPath, presentation: true);
  Future<void> _playSfx(String assetPath, {bool presentation = false}) async {
    if (!presentation &&
        _cardAudioOwner != null &&
        (assetPath == 'sfx/play.mp3' || assetPath == 'sfx/capture.mp3')) {
      return;
    }
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isSoundEnabled) {
        final globalSettings = _ref.read(globalSettingsProvider);
        final overrideUrl = globalSettings.sfxOverrides[assetPath];

        Source? source;
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          source = UrlSource(overrideUrl);
        } else {
          // Zero-network fallback: use procedural embedded audio
          final defaultDataUri = DefaultAudioAssets.getSfx(assetPath);
          if (defaultDataUri != null) {
            source = _localSource(defaultDataUri);
          }
        }

        if (source != null) {
          await _sfxPlayer.setVolume(settings.soundVolume);
          await _sfxPlayer
              .play(source)
              .then((_) {
                handleInteraction(); // Success! Mark interaction and rescue music
              })
              .catchError((e) {
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
    super.dispose();
  }
}

final multimediaServiceProvider = ChangeNotifierProvider<MultimediaService>((
  ref,
) {
  // Switching back to native local mode disposes the old online audio players.
  ref.watch(nativeOnlineEnabledProvider);
  final service = MultimediaService(ref);
  return service;
});
