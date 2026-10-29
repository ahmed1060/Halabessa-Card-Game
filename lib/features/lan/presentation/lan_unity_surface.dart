import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/native_play_provider.dart';
import '../../game/presentation/providers/card_feedback.dart';
import '../../game/presentation/providers/unity_communication_service.dart';
import '../../game/presentation/providers/unity_layer_provider.dart';
import '../../game/presentation/widgets/unity_game_view.dart';
import '../../game/presentation/widgets/unity_persistent_overlay.dart';
import '../data/lan_connection.dart';

/// Renderer state cannot be inherited from the online/global container. In
/// particular, this bridge must read the LAN replica and its private local UID.
List<Override> lanUnityOverrides({
  required bool enabled,
  UnityCommunicationService Function(Ref)? bridgeFactory,
}) => [
  localUnityEnabledProvider.overrideWithValue(enabled),
  unityLayerVisibilityProvider.overrideWith((_) => false),
  unityInitializedProvider.overrideWith((_) => false),
  unityFailedProvider.overrideWith((_) => false),
  unityVisualSuspendedProvider.overrideWith((_) => false),
  unityCardInteractionsReadyProvider.overrideWith((_) => false),
  unityCardUiReadyProvider.overrideWith((_) => false),
  unityLayerActiveProvider.overrideWith(
    (ref) =>
        ref.watch(unityLayerVisibilityProvider) &&
        ref.watch(unityInitializedProvider) &&
        !ref.watch(unityFailedProvider),
  ),
  unityCommunicationServiceProvider.overrideWith((ref) {
    final service = (bridgeFactory ?? UnityCommunicationService.new)(ref)
      ..init();
    ref.onDispose(service.dispose);
    return service;
  }),
  cardFeedbackProvider.overrideWith((ref) {
    final feedback = CardFeedback(ref);
    ref.onDispose(feedback.dispose);
    return feedback;
  }),
];

/// Same private provider scope as the board, never the complete host container.
class LanUnitySurface extends ConsumerStatefulWidget {
  const LanUnitySurface({
    super.key,
    required this.connection,
    required this.child,
    this.unityView = const UnityGameView(),
  });
  final LanConnection connection;
  final Widget child, unityView;
  @override
  ConsumerState<LanUnitySurface> createState() => _LanUnitySurfaceState();
}

class _LanUnitySurfaceState extends ConsumerState<LanUnitySurface> {
  late final _bridge = ref.read(unityCommunicationServiceProvider);
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.connection.addListener(_connectionChanged);
  }

  void _connectionChanged() {
    final generation = ++_generation;
    if (widget.connection.status != 'connected') {
      ref.read(unityVisualSuspendedProvider.notifier).state = true;
      _bridge.setVisualForeground(false);
    } else {
      // Let the replica and measured hand anchors consume the fresh snapshot
      // first. Never replay missed moves from the previous connection.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        ref.read(unityVisualSuspendedProvider.notifier).state = false;
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.connection.removeListener(_connectionChanged);
    _bridge.clearVisuals();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      UnityPersistentOverlay(unityView: widget.unityView),
      widget.child,
    ],
  );
}
