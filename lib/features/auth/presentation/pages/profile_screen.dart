import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import '../providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: ThemeConfig.darkGreen,
        body: Center(child: Text('not_logged_in'.tr(), style: const TextStyle(color: Colors.white))),
      );
    }

    final winRate = user.gamesPlayed > 0 ? (user.wins / user.gamesPlayed * 100).toStringAsFixed(1) : "0.0";
    const nextLevelXP = 100; // Simplified for now
    final currentXP = user.points % 100;
    final level = (user.points / 100).floor() + 1;

    return Scaffold(
      backgroundColor: ThemeConfig.darkGreen,
      appBar: AppBar(
        title: Text('player_profile'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeConfig.darkGreen,
              Colors.black.withOpacity(0.8),
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
                    UserAvatar(user: user, radius: 60),
                    const SizedBox(height: 16),
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: ThemeConfig.goldAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'level'.tr(args: [level.toString()]),
                        style: const TextStyle(color: ThemeConfig.goldAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildXPBar(context, currentXP, nextLevelXP),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Statistics Section
              _buildSectionHeader(context, 'career_stats'.tr()),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'win_rate'.tr(), "$winRate%", Icons.trending_up, Colors.green)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildStatCard(context, 'games_played'.tr(), user.gamesPlayed.toString(), Icons.play_circle_outline, Colors.blue)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildStatCard(context, 'best_score'.tr(), user.bestScore.toString(), Icons.emoji_events, Colors.orange)),
                   const SizedBox(width: 16),
                   Expanded(child: _buildStatCard(context, 'points'.tr(), user.points.toString(), Icons.stars, Colors.amber)),
                ],
              ),
              const SizedBox(height: 40),

              // Achievements Section
              _buildSectionHeader(context, 'achievements_title'.tr()),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAchievementBadge(context, "Welcome", Icons.handshake, Colors.blue),
                    _buildAchievementBadge(context, "Winner", Icons.workspace_premium, Colors.amber),
                    _buildAchievementBadge(context, "Tafweet King", Icons.auto_awesome, Colors.purple),
                    if (user.points > 1000) _buildAchievementBadge(context, "Pro", Icons.star, Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Auth Actions
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text('log_out'.tr(), style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  ref.read(authRepositoryProvider).signOut();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: 100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
