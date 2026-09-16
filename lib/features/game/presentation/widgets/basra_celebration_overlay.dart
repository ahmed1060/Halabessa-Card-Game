import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/theme_config.dart';

/// An energetic celebration overlay displayed whenever a player achieves
/// a Basra (sweeping the entire table clean in Halabessa).
class BasraCelebrationOverlay extends StatefulWidget {
  final String capturingTeam;
  final bool isMyTeam;
  final VoidCallback onDismissed;

  const BasraCelebrationOverlay({
    super.key,
    required this.capturingTeam,
    required this.isMyTeam,
    required this.onDismissed,
  });

  @override
  State<BasraCelebrationOverlay> createState() => _BasraCelebrationOverlayState();
}

class _BasraCelebrationOverlayState extends State<BasraCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    HapticFeedback.heavyImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.15)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 15,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = widget.capturingTeam == 'teamA'
        ? ThemeConfig.primaryTeal
        : ThemeConfig.goldAccent;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        teamColor.withOpacity(0.95),
                        Colors.black.withOpacity(0.90),
                      ],
                      radius: 0.85,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: ThemeConfig.goldAccent.withOpacity(0.9),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teamColor.withOpacity(0.6 * _glowAnimation.value),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shimmering crown or sparkles icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, color: ThemeConfig.goldAccent, size: 28),
                          const SizedBox(width: 8),
                          const Text('👑', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 8),
                          Icon(Icons.star_rounded, color: ThemeConfig.goldAccent, size: 28),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Egyptian Calligraphy / Title
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            ThemeConfig.goldAccent,
                            Colors.amber.shade200,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'حلبسة!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.black87, offset: Offset(0, 4), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),

                      // Subtitle
                      Text(
                        'BASRA SWEEP',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: ThemeConfig.fontHeading,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Reward / Team badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          widget.isMyTeam
                              ? 'basra_my_team'.tr()
                              : 'basra_other_team'.tr(),
                          style: TextStyle(
                            color: widget.isMyTeam ? Colors.tealAccent : Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
