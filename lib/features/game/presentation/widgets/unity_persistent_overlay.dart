import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'unity_game_view.dart';
import '../providers/unity_layer_provider.dart';
import '../../../../core/utils/web_registry.dart';
import 'game_table_background.dart';

class UnityPersistentOverlay extends ConsumerStatefulWidget {
  const UnityPersistentOverlay({
    super.key,
    this.unityView = const UnityGameView(),
  });

  final Widget unityView;

  @override
  ConsumerState<UnityPersistentOverlay> createState() =>
      _UnityPersistentOverlayState();
}

class _UnityPersistentOverlayState
    extends ConsumerState<UnityPersistentOverlay> {
  bool _hasMountedEngine = false;

  @override
  Widget build(BuildContext context) {
    final requested = ref.watch(unityLayerVisibilityProvider);
    final active = ref.watch(unityLayerActiveProvider);
    final failed = ref.watch(unityFailedProvider);

    if (kIsWeb) {
      ref.listen<bool>(unityLayerActiveProvider, (_, next) {
        // Flutter owns the hand hit targets and HUD. Native rendering receives
        // visual poses, not duplicate DOM taps beneath Flutter's canvas.
        setWebUnityPointerEvents(false);
      });
    }

    // Do not allocate a WebGL/native view in the lobby or in 2D mode. Once
    // mounted, retain the same view so navigation cannot create two engines.
    _hasMountedEngine = _hasMountedEngine || (requested && !failed);
    if (!_hasMountedEngine) return const SizedBox.shrink();

    // Paint the platform view while loading: Opacity(0) skips the paint that
    // attaches HtmlElementView, so waiting for READY before painting deadlocks
    // startup. The Navigator's opaque Flutter table stays above this until the
    // handshake; unityLayerActiveProvider still alone controls the hand-off.
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Opacity(
          opacity: requested && !failed ? 1 : 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (active) const GameTableBackground(),
              widget.unityView,
            ],
          ),
        ),
      ),
    );
  }
}
