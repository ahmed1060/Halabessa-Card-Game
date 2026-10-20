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
  bool _disposed = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void bind(String scope, {required bool ownsAudio}) {
    if (_disposed) return;
    if (scope != _scope) {
      _scope = scope;
      _seen.clear();
    }
    _releaseAudio?.call();
    _releaseAudio = null;
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

  void pick() => _haptic('light');
  void reject() => _haptic('error');
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
  }
}
