import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'unity_game_view.dart';
import '../providers/unity_layer_provider.dart';

class UnityPersistentOverlay extends ConsumerWidget {
  const UnityPersistentOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(unityLayerVisibilityProvider);
    final isInitialized = ref.watch(unityInitializedProvider);
    
    // We need the canvas to be "visible" to the browser (opacity > 0) 
    // for the WebGL context to be successfully created.
    double opacity = 0.0;
    if (isVisible) {
      opacity = 1.0;
    } else if (!isInitialized) {
      // Keep it technically visible during boot to satisfy WebGL context requirements
      opacity = 0.01;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: opacity,
              child: const UnityGameView(),
            ),
          ),
        ),
        // Global Initialization Overlay (Shows only once)
        if (!isInitialized && isVisible)
          Positioned.fill(
            child: Container(
              color: Colors.black, // Dark background for the very first load
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 120),
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      "Warming up 3D Engine...",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This will only happen once.",
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
