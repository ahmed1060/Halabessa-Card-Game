import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import '../../../../core/theme/theme_config.dart';
import '../../domain/models/match_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/services/multimedia_service.dart';
import '../../domain/providers/game_providers.dart';

class MatchSummaryDialog extends ConsumerStatefulWidget {
  final MatchState matchState;
  final String winnerTeam;

  const MatchSummaryDialog({
    super.key,
    required this.matchState,
    required this.winnerTeam,
  });

  @override
  ConsumerState<MatchSummaryDialog> createState() => _MatchSummaryDialogState();
}

class _MatchSummaryDialogState extends ConsumerState<MatchSummaryDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _xpAnimation;
  
  int _starsDisplay = 0;
  int _coinsDisplay = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _xpAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOutCubic),
    );

    _controller.addListener(() {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;
      
      final earnedStars = widget.matchState.earnedStars[currentUser.uid] ?? 0;
      final earnedCoins = widget.matchState.earnedCoins[currentUser.uid] ?? 0;
      
      setState(() {
        _starsDisplay = (_controller.value * 2.5).clamp(0.0, 1.0) == 1.0 
            ? earnedStars 
            : (_controller.value * 2.5 * earnedStars).toInt();
            
        _coinsDisplay = (_controller.value * 2.5).clamp(0.0, 1.0) == 1.0 
            ? earnedCoins 
            : (_controller.value * 2.5 * earnedCoins).toInt();
      });
    });

    _controller.forward();

    // Trigger Victory/Defeat SFX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;
      final myIndex = widget.matchState.playerIds.indexOf(currentUser.uid);
      final myTeam = (myIndex == 0 || myIndex == 2) ? 'teamA' : 'teamB';
      final isWinner = myTeam == widget.winnerTeam;
      
      if (isWinner) {
        ref.read(multimediaServiceProvider).playSfx('sfx/win.mp3');
      } else {
        ref.read(multimediaServiceProvider).playSfx('sfx/lose.mp3');
      }
    });
  }

  void _onPlayAgain(BuildContext context, dynamic currentUser) {
    Navigator.of(context).pop();
    final isOffline = widget.matchState.id.startsWith('OFFLINE_');
    if (isOffline) {
      ref.read(matchStateProvider.notifier).startOfflinePracticeMatch(
        currentUser.uid,
        currentUser.displayName ?? 'Player',
      );
    } else {
      ref.read(matchStateProvider.notifier).voteRematch(currentUser.uid, true);
    }
  }

  void _onReturnHome(BuildContext context) {
    Navigator.of(context).pop();
    ref.read(matchStateProvider.notifier).leaveMatch();
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final myIndex = widget.matchState.playerIds.indexOf(currentUser.uid);
    final myTeam = (myIndex == 0 || myIndex == 2) ? 'teamA' : 'teamB';
    final isWinner = myTeam == widget.winnerTeam;
    
    final earnedStars = widget.matchState.earnedStars[currentUser.uid] ?? 0;
    final earnedCoins = widget.matchState.earnedCoins[currentUser.uid] ?? 0;

    // Calculate level progress
    final currentPoints = currentUser.points;
    final pointsForNextLevel = (currentUser.level * 1000);
    final progress = (currentPoints % 1000) / 1000.0;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isWinner ? Colors.amber.withOpacity(0.5) : Colors.white24,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isWinner ? Colors.amber : Colors.blue).withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Result Title
              Text(
                isWinner ? 'victory'.tr().toUpperCase() : 'defeat'.tr().toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isWinner ? Colors.amber : Colors.white70,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isWinner ? 'great_play'.tr() : 'better_luck'.tr(),
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Rewards Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _RewardItem(
                    label: 'stars_label'.tr(),
                    value: _starsDisplay,
                    icon: Icons.star_rounded,
                    color: Colors.amber,
                    isPositive: earnedStars >= 0,
                  ),
                  _RewardItem(
                    label: 'coins_label'.tr(),
                    value: _coinsDisplay,
                    icon: Icons.monetization_on_rounded,
                    color: Colors.orange,
                    isPositive: earnedCoins >= 0,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Level Progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'level_label'.tr(args: [currentUser.level.toString()]),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _xpAnimation,
                        builder: (context, child) {
                          return Container(
                            height: 12,
                            width: 292 * progress * _xpAnimation.value,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.cyan],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Action Buttons: Return Home & Play Again
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _onReturnHome(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home_rounded, size: 18, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            'return_home'.tr(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFAA7C11)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeConfig.goldAccent.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _onPlayAgain(context, currentUser),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.replay_rounded, color: Colors.black, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'play_again'.tr().toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isPositive;

  const _RewardItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text(
          '${isPositive ? "+" : ""}$value',
          style: TextStyle(
            color: isPositive ? color : Colors.redAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }
}

// Simple placeholder for ElevatorButton if not available in project
class ElevatorButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const ElevatorButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A4A4A), Color(0xFF2D2D2D)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 2,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
