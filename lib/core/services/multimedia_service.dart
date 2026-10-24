import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/global_settings_provider.dart';
import 'game_audio_sources.dart';
import '../providers/native_play_provider.dart';

class MultimediaService extends ChangeNotifier {
  final AudioPlayer _musicPlayer;
  final AudioPlayer _sfxPlayer;
  final AudioPlayer Function() _createPresentationPlayer;
  final List<AudioPlayer> _presentationVoices = [];
  int _nextPresentationVoice = 0;
  AudioPlayer _presentationVoice() {
    if (_presentationVoices.length < 3) {
      final voice = _createPresentationPlayer();
      _presentationVoices.add(voice);
      return voice;
    }
    final voice = _presentationVoices[_nextPresentationVoice];
    _nextPresentationVoice = (_nextPresentationVoice + 1) % 3;
    return voice;
  }

  final Ref _ref;

  MultimediaService(
    this._ref, {
    AudioPlayer? musicPlayer,
    AudioPlayer? sfxPlayer,
    AudioPlayer Function()? presentationPlayerFactory,
  }) : _musicPlayer = musicPlayer ?? AudioPlayer(),
       _sfxPlayer = sfxPlayer ?? AudioPlayer(),
       _createPresentationPlayer =
           presentationPlayerFactory ?? AudioPlayer.new {
    // Notify listeners when state changes so UI can update icons
    _musicPlayer.onPlayerStateChanged.listen((_) => notifyListeners());
    _sfxPlayer.onPlayerStateChanged.listen((_) => notifyListeners());

    // Auto-rescue music when global settings overrides are loaded
    _ref.listen(globalSettingsProvider, (previous, next) {
      if (_musicWanted &&
          _currentMusicPath != null &&
          (_roomMusic
              ? previous?.roomMusicOverrideUrl != next.roomMusicOverrideUrl
              : previous?.musicOverrideUrl != next.musicOverrideUrl)) {
        debugPrint(
          'MultimediaService: Global settings loaded. Rescuing pending music: $_pendingMusic',
        );
        _resumeMusic();
      }
    });

    // Stop music immediately if disabled in settings, or update volume
    _ref.listen(settingsProvider, (previous, next) {
      if (previous?.isMusicEnabled == true && next.isMusicEnabled == false) {
        stopMusic();
      } else if (previous?.isMusicEnabled == false &&
          next.isMusicEnabled == true) {
        if (_currentMusicPath != null) {
          _resumeMusic();
        }
      } else if (previous?.musicVolume != next.musicVolume) {
        _musicPlayer.setVolume(next.musicVolume);
      }

      if (previous?.soundVolume != next.soundVolume) {
        _sfxPlayer.setVolume(next.soundVolume);
        for (final voice in _presentationVoices) {
          voice.setVolume(next.soundVolume);
        }
      }
      if (previous?.isSoundEnabled == true && !next.isSoundEnabled) {
        stopSfx();
      }
    });
  }

  // Web Autoplay Handling
  bool _hasInteracted = false;
  String? _pendingMusic;

  void handleInteraction() {
    final first = !_hasInteracted;
    _hasInteracted = true;
    if (first) {
      debugPrint('MultimediaService: Interaction detected. Rescuing audio...');
      notifyListeners();
    }
    if (_pendingMusic != null) {
      _pendingMusic = null;
      _resumeMusic();
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
  bool _roomMusic = false, _currentLoop = true, _musicWanted = false;
  int _musicRequest = 0;
  String? _lastPlayedUrl;
  String? get currentMusicPath => _currentMusicPath;
  PlayerState get musicState => _musicPlayer.state;
  PlayerState get sfxState => _sfxPlayer.state;

  Stream<PlayerState> get musicStateStream => _musicPlayer.onPlayerStateChanged;
  Stream<PlayerState> get sfxStateStream => _sfxPlayer.onPlayerStateChanged;

  void _resumeMusic() {
    final path = _currentMusicPath;
    if (path != null) {
      _playMusicContext(path, room: _roomMusic, loop: _currentLoop);
    }
  }

  Future<void> playMusic(String assetPath, {bool loop = true}) =>
      _playMusicContext(assetPath, room: false, loop: loop);

  Future<void> playRoomMusic(String assetPath, {bool loop = true}) =>
      _playMusicContext(assetPath, room: true, loop: loop);

  Future<void> _playMusicContext(
    String assetPath, {
    required bool room,
    required bool loop,
  }) async {
    final request = ++_musicRequest;
    _currentMusicPath = assetPath;
    _roomMusic = room;
    _currentLoop = loop;
    _musicWanted = true;
    try {
      final settings = _ref.read(settingsProvider);
      if (!settings.isMusicEnabled) return;

      if (!_hasInteracted) {
        _pendingMusic = assetPath;
        return;
      }

      final offline = _ref.read(offlineSessionProvider);
      final global = offline ? null : _ref.read(globalSettingsProvider);
      final overrideUrl = room
          ? global?.roomMusicOverrideUrl
          : global?.musicOverrideUrl;
      final source = GameAudioSources.resolve(
        assetPath,
        overrideUrl: overrideUrl,
        allowRemote: !offline,
      );
      if (source == null) return;
      final identity = overrideUrl == null || overrideUrl.isEmpty
          ? 'bundled:$assetPath:$loop'
          : '$overrideUrl:$loop';

      // Force restart if different URL even if playing
      if (_musicPlayer.state == PlayerState.playing &&
          _lastPlayedUrl == identity) {
        await _musicPlayer.setVolume(settings.musicVolume);
        return;
      }

      await _musicPlayer.setVolume(settings.musicVolume);
      if (request != _musicRequest) return;
      await _musicPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      if (request != _musicRequest ||
          !_ref.read(settingsProvider).isMusicEnabled) {
        return;
      }
      try {
        await _musicPlayer.play(source);
      } catch (error) {
        if (request != _musicRequest) return;
        if (error.toString().contains('NotAllowedError')) {
          _pendingMusic = assetPath;
          return;
        }
        // A broken custom upload must not silence the selected bundled track.
        if (overrideUrl == null || overrideUrl.isEmpty) rethrow;
        await _musicPlayer.play(
          GameAudioSources.resolve(assetPath, allowRemote: false)!,
        );
      }
      if (request != _musicRequest) return;
      _lastPlayedUrl = identity;
      _pendingMusic = null;
      notifyListeners();
    } catch (e) {
      debugPrint('MultimediaService: Failed to play room music: $e');
    }
  }

  Future<void> stopMusic() async {
    _musicRequest++;
    _musicWanted = false;
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
  Object? _deckAudioOwner;
  void Function() ownDeckPresentationAudio(Object owner) {
    _deckAudioOwner = owner;
    return () {
      if (identical(_deckAudioOwner, owner)) _deckAudioOwner = null;
    };
  }

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
        _deckAudioOwner != null &&
        (assetPath == 'sfx/cut.mp3' || assetPath == 'sfx/shuffle.mp3')) {
      return;
    }
    if (!presentation &&
        _cardAudioOwner != null &&
        (assetPath == 'sfx/play.mp3' || assetPath == 'sfx/capture.mp3')) {
      return;
    }
    try {
      final settings = _ref.read(settingsProvider);
      if (settings.isSoundEnabled) {
        final offline = _ref.read(offlineSessionProvider);
        final overrideUrl = offline
            ? null
            : _ref.read(globalSettingsProvider).sfxOverrides[assetPath];
        final source = GameAudioSources.resolve(
          assetPath,
          overrideUrl: overrideUrl,
          allowRemote: !offline,
        );

        if (source != null) {
          final player = presentation ? _presentationVoice() : _sfxPlayer;
          await player.setVolume(settings.soundVolume);
          // Preferences may change while a platform player is initializing.
          if (!_ref.read(settingsProvider).isSoundEnabled) return;
          await player
              .play(source)
              .then((_) {
                handleInteraction(); // Success! Mark interaction and rescue music
              })
              .catchError((e) async {
                if (e.toString().contains('NotAllowedError')) {
                  debugPrint('MultimediaService: Autoplay blocked for SFX.');
                } else {
                  debugPrint('MultimediaService: SFX Playback error: $e');
                  if (overrideUrl != null &&
                      overrideUrl.isNotEmpty &&
                      _ref.read(settingsProvider).isSoundEnabled) {
                    final fallback = GameAudioSources.resolve(
                      assetPath,
                      allowRemote: false,
                    );
                    if (fallback != null) await player.play(fallback);
                  }
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
      await Future.wait(_presentationVoices.map((voice) => voice.stop()));
    } catch (e) {
      debugPrint('MultimediaService: Failed to stop SFX: $e');
    }
  }

  @override
  void dispose() {
    _musicRequest++;
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    for (final voice in _presentationVoices) {
      voice.dispose();
    }
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
