import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';
import 'package:halabessa/features/home/presentation/widgets/daily_streak_dialog.dart';
import '../providers/auth_providers.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/username_onboarding_overlay.dart';
import '../../domain/models/app_user.dart';

class ProfileAchievement {
  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final int currentProgress;
  final int targetProgress;

  const ProfileAchievement({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.currentProgress,
    required this.targetProgress,
  });
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _hasCheckedOnboarding = false;
  DailyStreakStatus? _streakStatus;

  @override
  void initState() {
    super.initState();
    _loadStreakStatus();
  }

  Future<void> _loadStreakStatus() async {
    final status = await DailyStreakService.checkStatus();
    if (mounted) {
      setState(() => _streakStatus = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: ThemeConfig.darkBg,
        body: Center(child: Text('not_logged_in'.tr(), style: const TextStyle(color: Colors.white))),
      );
    }

    final winRate = user.gamesPlayed > 0 ? (user.wins / user.gamesPlayed * 100).toStringAsFixed(1) : "0.0";
    final level = user.level;
    const nextLevelXP = 1000;
    final currentXP = user.points % 1000;

    // Mandatory Username Check — guarded to run only once
    if (user.username == null && !_hasCheckedOnboarding) {
      _hasCheckedOnboarding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) => const UsernameOnboardingOverlay(),
        );
      });
    }

    return Scaffold(
      backgroundColor: ThemeConfig.darkBg,
      appBar: AppBar(
        title: Text('player_profile'.tr(), style: const TextStyle(fontFamily: ThemeConfig.fontHeading)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConfig.darkBg,
              Colors.black.withOpacity(0.85),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section: Avatar & Level
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(user: user, radius: 60, onTap: () => _showAvatarPicker(context)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: ThemeConfig.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: ThemeConfig.fontHeading,
                              ),
                        ),
                        if (user.isAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'admin_badge'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    if (user.username != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: ThemeConfig.primaryTeal.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThemeConfig.goldAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        user.isAdmin ? 'admin_badge'.tr() : 'level_label'.tr(args: [level.toString()]),
                        style: const TextStyle(
                          color: ThemeConfig.goldAccent, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!user.isAdmin) _buildXPBar(context, currentXP, nextLevelXP),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Interactive Daily Streak Card
              _buildDailyStreakBanner(context, _streakStatus),
              const SizedBox(height: 32),

              // Statistics Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(context, 'career_stats'.tr()),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
                    icon: const Icon(Icons.leaderboard_rounded, color: ThemeConfig.goldAccent, size: 16),
                    label: Text(
                      'view_leaderboard'.tr(),
                      style: const TextStyle(color: ThemeConfig.goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'win_rate'.tr(), "$winRate%", Icons.trending_up_rounded, Colors.greenAccent)),
                   const SizedBox(width: 14),
                   Expanded(child: _buildStatCard(context, 'games_played'.tr(), user.gamesPlayed.toString(), Icons.play_circle_outline_rounded, Colors.lightBlueAccent)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'wins_losses_label'.tr(), "${user.wins} / ${user.losses}", Icons.sports_score_rounded, Colors.amberAccent)),
                   const SizedBox(width: 14),
                   Expanded(child: _buildStatCard(context, 'best_score'.tr(), user.bestScore.toString(), Icons.emoji_events_rounded, Colors.orangeAccent)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'stars'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.points.toString(), Icons.stars_rounded, ThemeConfig.goldAccent)),
                   const SizedBox(width: 14),
                   Expanded(child: _buildStatCard(context, 'coins'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.coins.toString(), Icons.monetization_on_rounded, Colors.amber)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'diamonds'.tr(), user.isAdmin ? 'status_infinity'.tr() : user.diamonds.toString(), Icons.diamond_rounded, ThemeConfig.primaryTeal)),
                ],
              ),
              const SizedBox(height: 36),

              // Achievements Section
              _buildSectionHeader(context, 'achievements_title'.tr()),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final achievements = _buildAchievementsList(user, _streakStatus);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: achievements.map((ach) => _buildAchievementBadge(context, ach)).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Auth Actions
              const Divider(color: Colors.white10),
              
              // Change Profile Actions
              ListTile(
                leading: const Icon(Icons.password, color: Colors.blueAccent),
                title: Text('change_password_btn'.tr()),
                onTap: () => _showChangePasswordDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: Text('edit_display_name'.tr()),
                subtitle: Text('free_anytime'.tr(), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                onTap: () => _handleDisplayNameChange(context, user),
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email, color: ThemeConfig.goldAccent),
                title: Text('change_username_btn'.tr()),
                subtitle: Text(
                  user.isAdmin 
                    ? 'free_for_admin'.tr()
                    : (user.username == null 
                      ? 'first_time_free'.tr()
                      : ((user.inventory['username_change_ticket'] ?? 0) > 0 
                        ? 'use_ticket_btn'.tr() 
                        : 'no_tickets_message'.tr())),
                  style: TextStyle(
                    color: (user.isAdmin || user.username == null || (user.inventory['username_change_ticket'] ?? 0) > 0) 
                      ? ThemeConfig.goldAccent 
                      : Colors.white30,
                    fontSize: 12,
                  ),
                ),
                onTap: () => _handleUsernameChange(context, user),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text('log_out'.tr(), style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: ThemeConfig.darkBg,
                      title: Text('log_out'.tr(), style: const TextStyle(color: Colors.white)),
                      content: Text('log_out_confirm'.tr(), style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          onPressed: () {
                            ref.read(authRepositoryProvider).signOut();
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: Text('log_out'.tr()),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyStreakBanner(BuildContext context, DailyStreakStatus? status) {
    final currentStreak = status?.currentStreak ?? 1;
    final isClaimable = status?.isClaimableToday ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            isClaimable ? const Color(0xFF3B2D1B) : const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isClaimable ? ThemeConfig.goldAccent : Colors.white.withOpacity(0.12),
          width: isClaimable ? 1.5 : 1,
        ),
        boxShadow: isClaimable
            ? [
                BoxShadow(
                  color: ThemeConfig.goldAccent.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            HapticFeedback.lightImpact();
            final current = status ?? await DailyStreakService.checkStatus();
            if (context.mounted) {
              final claimed = await showDialog<bool>(
                context: context,
                builder: (ctx) => DailyStreakDialog(status: current),
              );
              if (claimed == true) {
                _loadStreakStatus();
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isClaimable ? ThemeConfig.goldAccent : Colors.orangeAccent).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isClaimable ? ThemeConfig.goldAccent : Colors.orangeAccent).withOpacity(0.4),
                    ),
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'streak_profile_banner'.tr(args: [currentStreak.toString()]),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: ThemeConfig.fontHeading,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isClaimable ? 'streak_ready_to_claim'.tr() : 'streak_claimed_today'.tr(),
                        style: TextStyle(
                          color: isClaimable ? ThemeConfig.goldAccent : Colors.white60,
                          fontSize: 12,
                          fontWeight: isClaimable ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isClaimable ? ThemeConfig.goldAccent : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isClaimable ? 'claim_reward'.tr() : 'day_label'.tr(args: [currentStreak.toString()]),
                        style: TextStyle(
                          color: isClaimable ? Colors.black : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isClaimable ? Icons.card_giftcard_rounded : Icons.chevron_right_rounded,
                        color: isClaimable ? Colors.black : Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ProfileAchievement> _buildAchievementsList(AppUser user, DailyStreakStatus? streak) {
    final streakDays = streak?.currentStreak ?? 0;
    return [
      ProfileAchievement(
        id: 'welcome',
        titleKey: 'achievement_welcome',
        descKey: 'achievement_welcome_desc',
        icon: Icons.handshake_rounded,
        color: Colors.blueAccent,
        isUnlocked: user.gamesPlayed >= 1,
        currentProgress: min(user.gamesPlayed, 1),
        targetProgress: 1,
      ),
      ProfileAchievement(
        id: 'winner',
        titleKey: 'achievement_winner',
        descKey: 'achievement_winner_desc',
        icon: Icons.emoji_events_rounded,
        color: Colors.amber,
        isUnlocked: user.wins >= 5,
        currentProgress: min(user.wins, 5),
        targetProgress: 5,
      ),
      ProfileAchievement(
        id: 'legend',
        titleKey: 'achievement_legend',
        descKey: 'achievement_legend_desc',
        icon: Icons.workspace_premium_rounded,
        color: ThemeConfig.goldAccent,
        isUnlocked: streakDays >= 7 || user.wins >= 50,
        currentProgress: min(max(streakDays, user.wins), 7),
        targetProgress: 7,
      ),
      ProfileAchievement(
        id: 'basra_hunter',
        titleKey: 'achievement_basra_hunter',
        descKey: 'achievement_basra_hunter_desc',
        icon: Icons.local_fire_department_rounded,
        color: Colors.deepOrangeAccent,
        isUnlocked: user.bestScore >= 40 || user.gamesPlayed >= 10,
        currentProgress: min(user.bestScore, 40),
        targetProgress: 40,
      ),
      ProfileAchievement(
        id: 'tafweet_king',
        titleKey: 'tafweet_king',
        descKey: 'tafweet_king_desc',
        icon: Icons.psychology_rounded,
        color: Colors.purpleAccent,
        isUnlocked: user.gamesPlayed >= 10 && user.winRate >= 0.55,
        currentProgress: min(user.gamesPlayed, 10),
        targetProgress: 10,
      ),
      ProfileAchievement(
        id: 'pro',
        titleKey: 'achievement_pro',
        descKey: 'achievement_pro_desc',
        icon: Icons.star_rounded,
        color: Colors.tealAccent,
        isUnlocked: user.points >= 1000,
        currentProgress: min(user.points, 1000),
        targetProgress: 1000,
      ),
    ];
  }

  void _showAchievementModal(BuildContext context, ProfileAchievement item) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: item.color.withOpacity(item.isUnlocked ? 0.6 : 0.2), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.color.withOpacity(item.isUnlocked ? 0.2 : 0.06),
                border: Border.all(color: item.color.withOpacity(item.isUnlocked ? 0.6 : 0.2), width: 2),
              ),
              child: Icon(item.icon, color: item.isUnlocked ? item.color : Colors.white30, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              item.titleKey.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: ThemeConfig.fontHeading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.descKey.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: item.isUnlocked ? Colors.green.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.isUnlocked ? Colors.greenAccent : Colors.white24),
              ),
              child: Text(
                item.isUnlocked 
                    ? 'achievement_unlocked'.tr() 
                    : 'achievement_progress'.tr(args: [item.currentProgress.toString(), item.targetProgress.toString()]),
                style: TextStyle(
                  color: item.isUnlocked ? Colors.greenAccent : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AvatarPicker(),
    );
  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? localError;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeConfig.darkBg,
          title: Text('change_password_btn'.tr(), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'new_password_label'.tr(),
                  errorText: localError,
                ),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (localError != null) setDialogState(() => localError = null);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(labelText: 'confirm_password_label'.tr()),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context), 
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (passwordController.text != confirmController.text) {
                  setDialogState(() => localError = 'passwords_no_match'.tr());
                  return;
                }
                if (passwordController.text.length < 6) {
                  setDialogState(() => localError = 'min_3_chars'.tr());
                  return;
                }
                setDialogState(() => isUpdating = true);
                try {
                  await ref.read(authRepositoryProvider).updatePassword(passwordController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('password_updated_success'.tr())));
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() {
                      localError = e.toString();
                      isUpdating = false;
                    });
                  }
                }
              },
              child: isUpdating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('update'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDisplayNameChange(BuildContext context, AppUser user) async {
    final nameController = TextEditingController(text: user.displayName);
    String? localError;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeConfig.darkBg,
          title: Text('edit_display_name'.tr(), style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'display_name_label'.tr(),
              hintText: 'edit_name_hint'.tr(),
              errorText: localError,
              counterText: "",
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) {
              if (localError != null) setDialogState(() => localError = null);
            },
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context), 
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                final newName = nameController.text.trim();
                if (newName == user.displayName) {
                  Navigator.pop(context);
                  return;
                }
                if (newName.isEmpty) {
                  setDialogState(() => localError = 'min_3_chars'.tr());
                  return;
                }
                setDialogState(() => isUpdating = true);
                try {
                  await ref.read(authRepositoryProvider).updateProfile(displayName: newName);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_updated_success'.tr())));
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() {
                      localError = e.toString();
                      isUpdating = false;
                    });
                  }
                }
              },
              child: isUpdating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('update'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUsernameChange(BuildContext context, AppUser user) async {
    final hasTicket = user.isAdmin || user.username == null || (user.inventory['username_change_ticket'] ?? 0) > 0;
    
    if (!hasTicket) {
      _showNoTicketDialog(context);
      return;
    }

    final usernameController = TextEditingController(text: user.username ?? '');
    String? localError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeConfig.darkBg,
          title: Text('change_username_btn'.tr(), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: usernameController,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'username_label'.tr(),
                  prefixText: '@',
                  errorText: localError,
                  counterText: "",
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (localError != null) {
                    setDialogState(() => localError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              if (!user.isAdmin && user.username != null)
                Text(
                  'consumes_ticket_warning'.tr(),
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final newUsername = usernameController.text.trim().toLowerCase();
                
                if (newUsername.isEmpty || newUsername == user.username?.toLowerCase()) {
                  Navigator.pop(context);
                  return;
                }

                if (newUsername.length < 3) {
                  setDialogState(() => localError = 'min_3_chars'.tr());
                  return;
                }

                final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
                if (!validCharacters.hasMatch(newUsername)) {
                  setDialogState(() => localError = 'invalid_chars'.tr());
                  return;
                }

                try {
                  final isAvailable = await ref.read(authRepositoryProvider).isUsernameAvailable(newUsername);
                  if (!isAvailable) {
                    setDialogState(() => localError = 'username_taken'.tr());
                    return;
                  }

                  await ref.read(authRepositoryProvider).updateUsername(newUsername);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('username_updated_success'.tr())));
                  }
                } catch (e) {
                  setDialogState(() => localError = e.toString());
                }
              },
              child: Text('update'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoTicketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeConfig.darkBg,
        title: Text('username_change_ticket'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text('no_tickets_message'.tr(), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/store');
            },
            child: Text('buy_ticket_btn'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBar(BuildContext context, int current, int total) {
    double progress = (current / total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(ThemeConfig.goldAccent),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'xp_to_next_level'.tr(args: [current.toString(), total.toString()]),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        fontFamily: ThemeConfig.fontHeading,
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: ThemeConfig.fontHeading,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, ProfileAchievement item) {
    final unlocked = item.isUnlocked;
    return GestureDetector(
      onTap: () => _showAchievementModal(context, item),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 105,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: unlocked 
                          ? [item.color.withOpacity(0.25), item.color.withOpacity(0.08)]
                          : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: unlocked ? item.color.withOpacity(0.7) : Colors.white24,
                      width: unlocked ? 1.8 : 1,
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: item.color.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    item.icon,
                    color: unlocked ? item.color : Colors.white24,
                    size: 30,
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.white54, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.titleKey.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? 'achievement_unlocked'.tr() : '${item.currentProgress}/${item.targetProgress}',
              style: TextStyle(
                color: unlocked ? Colors.greenAccent : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
