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
    
    // We only block clicks if the splash is showing OR if Unity is explicitly requesting interaction (isVisible)
    final shouldBlockClicks = isVisible || (!isInitialized);

    return IgnorePointer(
      ignoring: !shouldBlockClicks,
      child: Stack(
        children: [
          // The Unity Camera Layer
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isVisible ? 1.0 : (isInitialized ? 0.0 : 0.01),
              child: const UnityGameView(),
            ),
          ),
          
          // The Initialization Overlay (Restored to "Old" Favorite Look)
          if (!isInitialized)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8), // Slightly transparent black
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png', height: 100),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Initializing Engine...",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
