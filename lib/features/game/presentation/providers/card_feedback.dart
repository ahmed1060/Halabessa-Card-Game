import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/multimedia_service.dart';
import 'visual_action_queue.dart';

final cardFeedbackProvider = Provider.autoDispose<CardFeedback>((ref) {
  final feedback = CardFeedback(ref);
  ref.onDispose(feedback.dispose);
  return feedback;
});

/// One sensory owner for both renderers; no match command or state writes.
class CardFeedback {
  final Ref _ref;
  CardFeedback(this._ref);
  String _scope = '';
  final _seen = <String>{};
  void Function()? _releaseAudio;
  void Function()? _releaseDeckAudio;
  bool _disposed = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void bind(
    String scope, {
    required bool ownsAudio,
    bool ownsDeckAudio = false,
  }) {
    if (_disposed) return;
    if (scope != _scope) {
      _scope = scope;
      _seen.clear();
    }
    _releaseAudio?.call();
    _releaseAudio = null;
    _releaseDeckAudio?.call();
    _releaseDeckAudio = null;
    if (ownsDeckAudio && cardJuiceEnabled) {
      try {
        _releaseDeckAudio = _ref
            .read(multimediaServiceProvider)
            .ownDeckPresentationAudio(this);
      } catch (_) {
        /* Optional adapters may omit presentation audio. */
      }
    }
    if (ownsAudio && cardJuiceEnabled) {
      try {
        _releaseAudio = _ref
            .read(multimediaServiceProvider)
            .ownCardPresentationAudio(this);
      } catch (_) {
        /* Optional media adapters may intentionally be absent. */
      }
    }
  }

  void pick() {
    if (_disposed || !cardJuiceEnabled) return;
    _haptic('light');
    unawaited(_audio('sfx/pick.mp3'));
  }

  void holdPulse() {
    if (_disposed || !cardJuiceEnabled) return;
    _haptic('light'); // No duplicate grab sound during the hold build-up.
  }

  void reject() {
    if (_disposed || !cardJuiceEnabled) return;
    _haptic('error');
    unawaited(_audio('sfx/return.mp3'));
  }

  void reveal(String id) => _gestureContact(id, 'sfx/reveal.mp3', 'medium');
  void deckAction(String id, String kind) {
    final path = switch (kind) {
      'cutSeparate' => 'sfx/pick.mp3',
      'shuffleMix' => 'sfx/shuffle.mp3',
      _ => 'sfx/cut.mp3',
    };
    _gestureContact(
      'deck:$id',
      path,
      kind == 'cutContact' || kind == 'shuffleContact' ? 'light' : 'none',
    );
  }

  void gestureSlam(String id) => _gestureContact(
    id,
    'sfx/slam_${id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 3}.mp3',
    'heavy',
  );
  void _gestureContact(String id, String path, String haptic) {
    if (_disposed || !cardJuiceEnabled || !_seen.add('$_scope:$id')) return;
    while (_seen.length > 256) {
      _seen.remove(_seen.first);
    }
    if (haptic != 'none') _haptic(haptic);
    unawaited(_audio(path));
  }

  void contact(String id, {bool slam = false}) {
    if (_disposed || !cardJuiceEnabled || !_seen.add('$_scope:$id')) return;
    while (_seen.length > 256) {
      _seen.remove(_seen.first);
    }
    _haptic(slam ? 'heavy' : 'medium');
    unawaited(_audio(slam ? 'sfx/capture.mp3' : 'sfx/play.mp3'));
  }

  Future<void> _audio(String path) async {
    try {
      if (_disposed ||
          !_foreground ||
          !_ref.read(settingsProvider).isSoundEnabled) {
        return;
      }
      await _ref.read(multimediaServiceProvider).playPresentationSfx(path);
    } catch (_) {
      /* Optional sound cannot fail a move or queue. */
    }
  }

  void _haptic(String kind) {
    if (_disposed ||
        !cardJuiceEnabled ||
        !_foreground ||
        !_ref.read(settingsProvider).isHapticsEnabled) {
      return;
    }
    final scope = _scope;
    unawaited(
      Future<void>.microtask(() async {
        try {
          if (_disposed ||
              scope != _scope ||
              !_foreground ||
              !_ref.read(settingsProvider).isHapticsEnabled) {
            return;
          }
          switch (kind) {
            case 'heavy':
              await HapticFeedback.heavyImpact();
            case 'medium':
              await HapticFeedback.mediumImpact();
            case 'error':
              await HapticFeedback.selectionClick();
            default:
              await HapticFeedback.lightImpact();
          }
        } catch (_) {
          /* Unsupported hardware is a valid silent path. */
        }
      }),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _releaseAudio?.call();
    _releaseAudio = null;
    _releaseDeckAudio?.call();
    _releaseDeckAudio = null;
  }
}
