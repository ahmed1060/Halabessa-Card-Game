import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/theme_config.dart';

class LoadingScreen extends StatelessWidget {
  final Stream<double> progressStream;
  const LoadingScreen({super.key, required this.progressStream});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.darkBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConfig.darkBg,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOutSine,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                onEnd: () {}, 
                child: Image.asset(
                  'assets/images/logo.png', // Correct logo path
                  width: 140,
                  height: 140,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.grid_view_rounded,
                    size: 80,
                    color: ThemeConfig.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Cycling Progress Steps
              const _CyclingLoadingText(),
              
              const SizedBox(height: 32),

              // Progress Bar
              StreamBuilder<double>(
                stream: progressStream,
                initialData: 0.0,
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0.0;
                  return Column(
                    children: [
                      Container(
                        width: 200,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 200 * progress,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [ThemeConfig.primaryTeal, ThemeConfig.goldAccent],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
      'loading_step_physics'.tr(),
      'loading_step_assets'.tr(),
      'loading_step_sync'.tr(),
      'loading_step_tables'.tr(),
      'loading_step_vibes'.tr(),
    ];
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
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
        _steps[_currentIndex].toUpperCase(),
        key: ValueKey(_currentIndex),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
