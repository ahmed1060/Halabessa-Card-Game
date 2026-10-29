import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../providers/unity_communication_service.dart';
import '../../domain/providers/game_providers.dart';
import '../providers/unity_layer_provider.dart';

class UnityGameView extends ConsumerStatefulWidget {
  const UnityGameView({super.key, this.nativeView});

  /// Test seam: keep the real subscriptions/lifecycle without a platform view.
  final Widget? nativeView;

  @override
  ConsumerState<UnityGameView> createState() => _UnityGameViewState();
}

class _UnityGameViewState extends ConsumerState<UnityGameView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    ref
        .read(unityCommunicationServiceProvider)
        .setVisualForeground(
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
              !ref.read(unityVisualSuspendedProvider),
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(unityCommunicationServiceProvider)
        .setVisualForeground(
          state == AppLifecycleState.resumed &&
              !ref.read(unityVisualSuspendedProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(unityVisualSuspendedProvider, (_, suspended) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      ref
          .read(unityCommunicationServiceProvider)
          .setVisualForeground(
            !suspended &&
                (lifecycle == null || lifecycle == AppLifecycleState.resumed),
          );
    });
    ref.listen(unityLayerActiveProvider, (_, __) {
      final state = ref.read(matchStateProvider);
      if (state != null) {
        ref.read(unityCommunicationServiceProvider).syncState(state);
      }
    });
    // Listen to match state changes and sync with Unity
    ref.listen(matchStateProvider, (previous, next) {
      if (next != null) {
        ref.read(unityCommunicationServiceProvider).syncState(next);
      } else {
        ref.read(unityCommunicationServiceProvider).clearVisuals();
      }
    });

    final comms = ref.watch(unityCommunicationServiceProvider);

    Widget unityWidget;
    if (widget.nativeView != null) {
      unityWidget = widget.nativeView!;
    } else if (kIsWeb) {
      unityWidget = HtmlElementView(
        viewType: 'unity-web-view',
        onPlatformViewCreated: (id) {
          // Fallback: If we don't get a UNITY_READY message soon,
          // we could mark as initialized here, but we prefer the bridge signal.
        },
      );
    } else {
      unityWidget = UnityWidget(
        onUnityCreated: (controller) {
          comms.setController(controller);

          // Initial sync of the current match state
          final matchState = ref.read(matchStateProvider);
          if (matchState != null) {
            comms.syncState(matchState);
            comms.setMode(matchState.mode.name);
          }
        },
        onUnityMessage: (message) {
          comms.handleUnityMessage(message);
        },
        onUnitySceneLoaded: (name) {
          // debugPrint("Unity Scene Loaded: $name");
        },
        useAndroidViewSurface: true, // For performance on Android
      );
    }

    return unityWidget;
  }
}
