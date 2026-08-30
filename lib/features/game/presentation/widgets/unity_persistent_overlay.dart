import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'unity_game_view.dart';
import '../providers/unity_layer_provider.dart';
import '../../../../core/utils/web_registry.dart';

class UnityPersistentOverlay extends ConsumerWidget {
  const UnityPersistentOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(unityLayerVisibilityProvider);
    final isInitialized = ref.watch(unityInitializedProvider);
    
    if (kIsWeb) {
      setWebUnityPointerEvents(isVisible);
    }
    
    // We keep Unity in the background. Clicks are handled by the layers ON TOP of it (Flutter)
    // unless isVisible is true (e.g. in GameBoardScreen), but even then, 
    // the GameBoardScreen is likely on top.
    
    return Positioned.fill(
      child: Stack(
        children: [
          // Background Unity view
          IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isVisible ? 1.0 : 0.0,
              child: const UnityGameView(),
            ),
          ),
          
          // Background Loading Feedback (Only show when Unity layer is requested to be visible)
          if (!isInitialized && isVisible)
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
  late final List<String> _steps;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _steps = [
      'loading_step_engine'.tr(),
      'loading_step_assets'.tr(),
      'loading_step_physics'.tr(),
      'loading_step_sync'.tr(),
      'loading_step_interface'.tr(),
    ];
    
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % _steps.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        _steps[_currentIndex],
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
