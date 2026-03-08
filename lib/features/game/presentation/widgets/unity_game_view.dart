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
      unityWidget = const HtmlElementView(viewType: 'unity-web-view');
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
          print("Unity Scene Loaded: $name");
        },
        useAndroidViewSurface: true, // For performance on Android
      );
    }

    return Container(
      child: Stack(
        children: [
          unityWidget,
          ValueListenableBuilder<bool>(
            valueListenable: comms.isReady,
            builder: (context, isReady, child) {
              if (isReady) return const SizedBox.shrink();
              return Container(
                color: const Color(0xFF0D1B2A), // Halabessa Dark Blue
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png', height: 100),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: Colors.white70),
                      const SizedBox(height: 10),
                      const Text(
                        "Initializing Engine...",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
