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
        // Global Initialization Overlay (Shows only once as the app's first splash)
        if (!isInitialized && isVisible)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D1B2A), // Dark Navy
                    Color(0xFF1B263B), // Deep Blue
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Subtle glowing circle behind logo
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.1),
                            blurRadius: 100,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game Logo with standard pulse animation
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1.0),
                          duration: const Duration(seconds: 2),
                          curve: Curves.easeInOutSine,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: 0.6 + (value - 0.8) * 2,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 180,
                                ),
                              ),
                            );
                          },
                          onEnd: () {}, // Handled by builder repeat if we used a controller, but a simple 1-shot or loop is fine
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Sleek Loading Bar
                        const SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            color: Colors.blueAccent,
                            backgroundColor: Colors.white10,
                            minHeight: 2,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const Text(
                          "INITIALIZING GAME ENGINE",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
