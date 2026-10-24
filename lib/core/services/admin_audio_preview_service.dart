import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'game_audio_sources.dart';

/// Separate from live match effects and lobby/room music. Never saves a choice.
class AdminAudioPreviewService extends ChangeNotifier
    with WidgetsBindingObserver {
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? activePath;
  bool isPlaying = false, _disposed = false;
  int _request = 0;

  AdminAudioPreviewService({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.add(
      _player.onPlayerComplete.listen((_) {
        activePath = null;
        isPlaying = false;
        if (!_disposed) notifyListeners();
      }),
    );
  }

  Future<void> play(
    String path, {
    String? overrideUrl,
    required double volume,
  }) async {
    final request = ++_request;
    final source = GameAudioSources.resolve(path, overrideUrl: overrideUrl);
    if (source == null) throw StateError('Unknown audio slot');
    await _player.stop();
    if (_disposed || request != _request) return;
    await _player.setVolume(volume);
    await _player.setReleaseMode(ReleaseMode.release);
    if (_disposed || request != _request) return;
    activePath = path;
    isPlaying = true;
    notifyListeners();
    try {
      await _player.play(source);
    } catch (_) {
      if (request == _request && !_disposed) {
        activePath = null;
        isPlaying = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    _request++;
    activePath = null;
    isPlaying = false;
    if (!_disposed) notifyListeners();
    await _player.stop();
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

final adminAudioPreviewProvider =
    ChangeNotifierProvider.autoDispose<AdminAudioPreviewService>((ref) {
      final service = AdminAudioPreviewService();
      ref.listen(settingsProvider, (_, next) {
        final path = service.activePath;
        if (path == null) return;
        final music = path.startsWith('music/');
        if (!(music ? next.isMusicEnabled : next.isSoundEnabled)) {
          unawaited(service.stop());
        } else {
          unawaited(
            service.setVolume(music ? next.musicVolume : next.soundVolume),
          );
        }
      });
      return service;
    });
