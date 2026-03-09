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
    
    // We keep Unity in the background. Clicks are handled by the layers ON TOP of it (Flutter)
    // unless isVisible is true (e.g. in GameBoardScreen), but even then, 
    // the GameBoardScreen is likely on top.
    
    return Positioned.fill(
      child: Stack(
        children: [
          // Background Unity view (partially visible while loading)
          IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isVisible ? 1.0 : (isInitialized ? 0.0 : 0.01),
              child: const UnityGameView(),
            ),
          ),
          
          // Background Loading Feedback (Old UI style)
          if (!isInitialized)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _CyclingLoadingText(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CyclingLoadingText extends StatefulWidget {
  const _CyclingLoadingText();

  @override
  State<_CyclingLoadingText> createState() => _CyclingLoadingTextState();
}

class _CyclingLoadingTextState extends State<_CyclingLoadingText> {
  int _currentIndex = 0;
  final List<String> _loadingSteps = [
    "Initializing Engine...",
    "Loading Card Assets...",
    "Readying Casino Environment...",
    "Configuring Card Physics...",
    "Synchronizing With Server...",
    "Finalizing Interface...",
  ];

  @override
  void initState() {
    super.initState();
    _startDisplayTimer();
  }

  void _startDisplayTimer() {
    // Cycle every 1.5 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return false;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _loadingSteps.length;
      });
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        _loadingSteps[_currentIndex],
        key: ValueKey(_currentIndex),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 1.1,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
