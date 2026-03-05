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
                onEnd: () {}, // Repeat logic usually handled by a controller, but this is simple pulse
                child: Image.asset(
                  'assets/images/gaming/game_logo.png',
                  width: 180,
                  height: 180,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.grid_view_rounded,
                    size: 100,
                    color: ThemeConfig.goldAccent,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Branded Loading Text
              Text(
                'loading'.tr().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontFamily: ThemeConfig.fontHeading,
                ),
              ),
              const SizedBox(height: 24),

              // Progress Bar
              StreamBuilder<double>(
                stream: progressStream,
                initialData: 0.0,
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0.0;
                  return Column(
                    children: [
                      Container(
                        width: 250,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 250 * progress,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [ThemeConfig.primaryTeal, ThemeConfig.goldAccent],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeConfig.goldAccent.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
