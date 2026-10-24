import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/models/global_settings.dart';
import 'package:halabessa/core/providers/global_settings_provider.dart';
import 'package:halabessa/core/providers/native_play_provider.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/services/admin_audio_preview_service.dart';
import 'package:halabessa/core/services/game_audio_sources.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/services/selected_audio_defaults.dart';

class _Player implements AudioPlayer {
  final played = <Source>[];
  final volumes = <double>[];
  final releaseModes = <ReleaseMode>[];
  final changes = StreamController<PlayerState>.broadcast(sync: true);
  final complete = StreamController<void>.broadcast(sync: true);
  Completer<void>? holdVolume;
  bool failRemote = false;
  @override
  PlayerState state = PlayerState.stopped;
  @override
  Stream<PlayerState> get onPlayerStateChanged => changes.stream;
  @override
  Stream<void> get onPlayerComplete => complete.stream;
  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    final gate = holdVolume;
    holdVolume = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode value) async {
    releaseModes.add(value);
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (failRemote && source is UrlSource) throw StateError('bad remote clip');
    played.add(source);
    state = PlayerState.playing;
    changes.add(state);
  }

  @override
  Future<void> stop() async {
    state = PlayerState.stopped;
    changes.add(state);
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await complete.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Global extends GlobalSettingsNotifier {
  _Global(GlobalSettings value) : super(listenRemote: false) {
    state = value;
  }
  void fixture(GlobalSettings value) {
    state = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all 16 registered routes load the exact selected WAV bytes from the bundle',
    () async {
      final manifest =
          jsonDecode(
                File(
                  'assets/audio/defaults/2026-10-24/selection.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(SelectedAudioDefaults.files, hasLength(16));
      final registered = <String>[];
      for (final kind in ['sfx', 'music']) {
        final screen = File(
          'lib/features/home/presentation/pages/admin_${kind}_management_screen.dart',
        ).readAsStringSync();
        registered.addAll(
          RegExp(r"'path':\s*'([^']+)'").allMatches(screen).map((m) => m[1]!),
        );
      }
      expect(SelectedAudioDefaults.files.keys.toSet(), registered.toSet());
      for (final entry in SelectedAudioDefaults.files.entries) {
        final data = await rootBundle.load('assets/${entry.value}');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        var hash = 2166136261;
        for (final byte in bytes) {
          hash = ((hash ^ byte) * 16777619) & 0xffffffff;
        }
        expect(hash, SelectedAudioDefaults.fingerprints[entry.key]);
        expect(hash, (manifest['selected'] as Map)[entry.key]['fnv1a32']);
        final source = GameAudioSources.resolve(entry.key)! as AssetSource;
        expect(source.path, entry.value);
      }
      expect(
        SelectedAudioDefaults.files['sfx/slam_0.mp3'],
        SelectedAudioDefaults.files['sfx/slam_2.mp3'],
      );
      expect(SelectedAudioDefaults.fingerprints['sfx/slam_0.mp3'], 3132475412);
      expect(
        SelectedAudioDefaults.files['music/bg_music.mp3'],
        isNot(SelectedAudioDefaults.files['music/room_music.mp3']),
      );
    },
  );
  test(
    'custom override wins online; offline and reset use the selected bundle',
    () {
      const remote = 'https://example.invalid/custom.wav';
      expect(
        (GameAudioSources.resolve('sfx/play.mp3', overrideUrl: remote)!
                as UrlSource)
            .url,
        remote,
      );
      expect(
        GameAudioSources.resolve(
          'sfx/play.mp3',
          overrideUrl: remote,
          allowRemote: false,
        ),
        isA<AssetSource>(),
      );
      expect(
        GameAudioSources.resolve('sfx/play.mp3', overrideUrl: ''),
        isA<AssetSource>(),
      );
      expect(GameAudioSources.resolve('sfx/unknown.mp3'), isNull);
    },
  );
  test('nullable snapshot can clear music without changing match settings', () {
    final old = GlobalSettings(
      musicOverrideUrl: 'home',
      roomMusicOverrideUrl: 'room',
      musicBackupUrl: 'backup',
      defaultTurnTimer: 21,
      defaultTargetScore: 52,
    );
    final cleared = old.copyWith(
      musicOverrideUrl: null,
      roomMusicOverrideUrl: null,
    );
    expect(cleared.musicOverrideUrl, isNull);
    expect(cleared.roomMusicOverrideUrl, isNull);
    expect(cleared.musicBackupUrl, 'backup');
    expect(cleared.defaultTurnTimer, 21);
    expect(cleared.defaultTargetScore, 52);
    expect(old.copyWith().musicOverrideUrl, 'home');
  });

  late ProviderContainer container;
  late _Player music, sfx;
  late _Global global;
  Future<MultimediaService> setup({
    bool offline = false,
    GlobalSettings? fixture,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    music = _Player();
    sfx = _Player();
    global = _Global(fixture ?? GlobalSettings());
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineSessionProvider.overrideWithValue(offline),
        globalSettingsProvider.overrideWith((ref) => global),
        multimediaServiceProvider.overrideWith(
          (ref) => MultimediaService(
            ref,
            musicPlayer: music,
            sfxPlayer: sfx,
            presentationPlayerFactory: _Player.new,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(multimediaServiceProvider);
  }

  Future<void> drain() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'room context survives interaction rescue, mute and re-enable',
    () async {
      final service = await setup(
        fixture: GlobalSettings(
          musicOverrideUrl: 'https://example.invalid/home.wav',
          roomMusicOverrideUrl: 'https://example.invalid/room.wav',
        ),
      );
      await service.playRoomMusic('music/room_music.mp3', loop: false);
      expect(music.played, isEmpty);
      service.handleInteraction();
      await drain();
      expect((music.played.last as UrlSource).url, contains('/room.wav'));
      expect(music.releaseModes.last, ReleaseMode.release);
      await container.read(settingsProvider.notifier).toggleMusic(false);
      await drain();
      expect(music.state, PlayerState.stopped);
      await container.read(settingsProvider.notifier).toggleMusic(true);
      await drain();
      expect((music.played.last as UrlSource).url, contains('/room.wav'));
      global.fixture(global.state.copyWith(roomMusicOverrideUrl: null));
      await drain();
      expect(
        (music.played.last as AssetSource).path,
        SelectedAudioDefaults.files['music/room_music.mp3'],
      );
    },
  );
  test(
    'offline music and sound use selected sources even with remote settings',
    () async {
      final service = await setup(
        offline: true,
        fixture: GlobalSettings(
          musicOverrideUrl: 'https://example.invalid/home.wav',
          sfxOverrides: {'sfx/play.mp3': 'https://example.invalid/play.wav'},
        ),
      );
      service.handleInteraction();
      await service.playMusic('music/bg_music.mp3');
      await service.playSfx('sfx/play.mp3');
      expect(music.played.single, isA<AssetSource>());
      expect(sfx.played.single, isA<AssetSource>());
    },
  );
  test(
    'bad custom audio falls back, muted sound stays silent, ownership stays deduplicated',
    () async {
      final service = await setup(
        fixture: GlobalSettings(
          musicOverrideUrl: 'https://example.invalid/bad.wav',
          sfxOverrides: {'sfx/play.mp3': 'https://example.invalid/bad.wav'},
        ),
      );
      music.failRemote = true;
      sfx.failRemote = true;
      service.handleInteraction();
      await service.playMusic('music/bg_music.mp3');
      await service.playSfx('sfx/play.mp3');
      expect(music.played.single, isA<AssetSource>());
      expect(sfx.played.single, isA<AssetSource>());
      final release = service.ownCardPresentationAudio(Object());
      await service.playSfx('sfx/play.mp3');
      expect(sfx.played, hasLength(1));
      release();
      await container.read(settingsProvider.notifier).toggleSound(false);
      await service.playSfx('sfx/play.mp3');
      expect(sfx.played, hasLength(1));
    },
  );
  test(
    'stopping or replacing music invalidates an older preparation',
    () async {
      final service = await setup();
      service.handleInteraction();
      final gate = Completer<void>();
      music.holdVolume = gate;
      final old = service.playMusic('music/bg_music.mp3');
      await drain();
      await service.stopMusic();
      gate.complete();
      await old;
      expect(music.played, isEmpty);
      final next = Completer<void>();
      music.holdVolume = next;
      final stale = service.playMusic('music/bg_music.mp3');
      await drain();
      await service.playRoomMusic('music/room_music.mp3');
      next.complete();
      await stale;
      expect(
        (music.played.single as AssetSource).path,
        SelectedAudioDefaults.files['music/room_music.mp3'],
      );
    },
  );
  test(
    'admin preview has its own player, replaces rows, respects volume and completes',
    () async {
      final player = _Player();
      final preview = AdminAudioPreviewService(player: player);
      await preview.play('sfx/play.mp3', volume: .3);
      expect(preview.activePath, 'sfx/play.mp3');
      expect(preview.isPlaying, isTrue);
      await preview.play('sfx/reveal.mp3', volume: .4);
      expect(preview.activePath, 'sfx/reveal.mp3');
      expect(player.volumes, [.3, .4]);
      player.complete.add(null);
      expect(preview.activePath, isNull);
      expect(preview.isPlaying, isFalse);
      await preview.play('music/room_music.mp3', volume: .2);
      await preview.setVolume(.1);
      expect(player.volumes.last, .1);
      preview.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(preview.activePath, isNull);
      await preview.stop();
      expect(preview.activePath, isNull);
      expect(player.state, PlayerState.stopped);
      preview.dispose();
    },
  );
}
