import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';
import 'package:halabessa/core/services/supabase_backend_service.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/theme/theme_config.dart';

class DailyStreakDialog extends ConsumerStatefulWidget {
  final DailyStreakStatus status;

  const DailyStreakDialog({super.key, required this.status});

  @override
  ConsumerState<DailyStreakDialog> createState() => _DailyStreakDialogState();
}

class _DailyStreakDialogState extends ConsumerState<DailyStreakDialog> {
  bool _isClaimed = false;
  bool _isClaiming = false;

  void _claim() async {
    if (_isClaimed || _isClaiming || !widget.status.isClaimableToday) return;

    setState(() => _isClaiming = true);
    HapticFeedback.heavyImpact();
    ref.read(multimediaServiceProvider).playSfx('sfx/purchase.mp3');

    try {
      final data = await SupabaseBackendService.call('claimDailyReward');
      await DailyStreakService.recordServerClaim(
        (data['streak'] as num).toInt(),
        serverDate: data['date'] as String?,
      );
    } on SupabaseBackendException catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'already_claimed'
                  ? 'Today\'s reward was already claimed.'
                  : 'Unable to claim the reward. Please try again.',
            ),
          ),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to claim the reward. Please try again.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isClaiming = false;
        _isClaimed = true;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF192638), Color(0xFF3B274C)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ThemeConfig.goldAccent.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeConfig.goldAccent.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 52,
                child: FittedBox(child: LanternWordmark()),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeConfig.goldAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: ThemeConfig.goldAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'daily_reward_title'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: ThemeConfig.fontHeading,
                                ),
                              ),
                              Text(
                                'streak_bonus'.tr(
                                  args: [status.currentStreak.toString()],
                                ),
                                style: TextStyle(
                                  color: ThemeConfig.goldAccent.withOpacity(
                                    0.9,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 7-day grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: status.schedule.map((reward) {
                  final bool isCurrent = reward.day == status.currentStreak;
                  final bool isPast = reward.day < status.currentStreak;
                  final bool isBigReward = reward.day == 7;

                  return Container(
                    width: isBigReward ? 140 : 66,
                    constraints: BoxConstraints(minHeight: 94 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0)),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? ThemeConfig.goldAccent.withOpacity(0.2)
                          : (isPast
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? ThemeConfig.goldAccent
                            : (isPast
                                  ? Colors.green.withOpacity(0.5)
                                  : Colors.white10),
                        width: isCurrent ? 2.0 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'day_label'.tr(args: [reward.day.toString()]),
                          style: TextStyle(
                            color: isCurrent
                                ? ThemeConfig.goldAccent
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPast)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 28,
                          )
                        else ...[
                          Icon(
                            reward.diamonds > 0
                                ? Icons.diamond
                                : Icons.monetization_on_rounded,
                            color: reward.diamonds > 0
                                ? ThemeConfig.primaryTeal
                                : ThemeConfig.goldAccent,
                            size: 26,
                          ),
                          Text(
                            '+${reward.coins}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (reward.diamonds > 0 && !isPast)
                          Text(
                            '+${reward.diamonds} 💎',
                            style: const TextStyle(
                              color: ThemeConfig.primaryTeal,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              // Native button semantics and keyboard activation, including pending state.
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC65B),
                    foregroundColor: const Color(0xFF192638),
                    minimumSize: const Size(48, 52),
                  ),
                  onPressed:
                      status.isClaimableToday && !_isClaimed && !_isClaiming
                      ? _claim
                      : null,
                  child: _isClaiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF192638),
                          ),
                        )
                      : Text(
                          _isClaimed || !status.isClaimableToday
                              ? 'claimed'.tr()
                              : '${'claim_reward'.tr()} (+${status.todayReward.coins} 🪙)',
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
