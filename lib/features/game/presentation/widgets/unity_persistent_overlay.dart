import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'unity_game_view.dart';
import '../providers/unity_layer_provider.dart';
import '../../../../core/utils/web_registry.dart';

class UnityPersistentOverlay extends ConsumerStatefulWidget {
  const UnityPersistentOverlay({super.key, this.unityView = const UnityGameView()});

  final Widget unityView;

  @override
  ConsumerState<UnityPersistentOverlay> createState() => _UnityPersistentOverlayState();
}

class _UnityPersistentOverlayState extends ConsumerState<UnityPersistentOverlay> {
  bool _hasMountedEngine = false;

  @override
  Widget build(BuildContext context) {
    final requested = ref.watch(unityLayerVisibilityProvider);
    final active = ref.watch(unityLayerActiveProvider);
    final failed = ref.watch(unityFailedProvider);

    if (kIsWeb) {
      ref.listen<bool>(unityLayerActiveProvider, (_, next) {
        setWebUnityPointerEvents(next);
      });
    }

    // Do not allocate a WebGL/native view in the lobby or in 2D mode. Once
    // mounted, retain the same view so navigation cannot create two engines.
    _hasMountedEngine = _hasMountedEngine || (requested && !failed);
    if (!_hasMountedEngine) return const SizedBox.shrink();

    // Keep Flutter's playable board visible throughout loading and failure.
    // A visible request alone is not evidence that Unity can render a scene.
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !active,
        child: Opacity(
          opacity: active ? 1 : 0,
          child: widget.unityView,
        ),
      ),
    );
  }
}
