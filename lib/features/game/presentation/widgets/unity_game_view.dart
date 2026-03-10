import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import '../providers/unity_communication_service.dart';
import '../../domain/providers/game_providers.dart';

class UnityGameView extends ConsumerStatefulWidget {
  const UnityGameView({super.key});

  @override
  ConsumerState<UnityGameView> createState() => _UnityGameViewState();
}

class _UnityGameViewState extends ConsumerState<UnityGameView> {
  @override
  Widget build(BuildContext context) {
    // Listen to match state changes and sync with Unity
    ref.listen(matchStateProvider, (previous, next) {
      if (next != null) {
        ref.read(unityCommunicationServiceProvider).syncState(next);
      }
    });

    final comms = ref.watch(unityCommunicationServiceProvider);

    Widget unityWidget;
    if (kIsWeb) {
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
