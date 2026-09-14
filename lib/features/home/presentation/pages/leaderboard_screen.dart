import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardCategory _selectedCategory = LeaderboardCategory.stars;

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider(_selectedCategory));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: ThemeConfig.goldAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'leaderboard_title'.tr(),
              style: const TextStyle(
                fontFamily: ThemeConfig.fontHeading,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D1B2A),
              const Color(0xFF1B263B).withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Category Tabs
            _buildCategoryTabs(),
            const SizedBox(height: 14),

            // Content: Podium + Scrollable List
            Expanded(
              child: leaderboardAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: ThemeConfig.goldAccent),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'error_prefix'.tr(args: [err.toString()]),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                data: (users) {
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'no_results'.tr(),
                        style: const TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  final top3 = users.take(3).toList();
                  final rest = users.skip(3).toList();

                  // Find user rank
                  int myRank = -1;
                  if (currentUser != null) {
                    final idx = users.indexWhere((u) => u.uid == currentUser.uid);
                    if (idx != -1) myRank = idx + 1;
                  }

                  return RefreshIndicator(
                    color: ThemeConfig.goldAccent,
                    onRefresh: () async {
                      ref.invalidate(leaderboardProvider(_selectedCategory));
                    },
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Top 3 Podium
                        if (top3.isNotEmpty) _buildPodium(top3),
                        const SizedBox(height: 24),

                        // Ranked List (4..N)
                        ...rest.asMap().entries.map((entry) {
                          final rank = entry.key + 4;
                          final player = entry.value;
                          final isMe = currentUser?.uid == player.uid;
                          return _buildPlayerRow(player, rank, isMe);
                        }),
                        const SizedBox(height: 90), // Spacing for sticky footer
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomSheet: currentUser != null ? _buildStickyUserRank(currentUser) : null,
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _buildTabButton(LeaderboardCategory.stars, 'tab_stars'.tr(), Icons.stars_rounded, ThemeConfig.goldAccent),
          _buildTabButton(LeaderboardCategory.wins, 'tab_wins'.tr(), Icons.emoji_events_rounded, Colors.amber),
          _buildTabButton(LeaderboardCategory.bestScore, 'tab_best_score'.tr(), Icons.local_fire_department_rounded, Colors.deepOrangeAccent),
        ],
      ),
    );
  }

  Widget _buildTabButton(LeaderboardCategory category, String title, IconData icon, Color activeColor) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = category);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor.withOpacity(0.5) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? activeColor : Colors.white54),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<AppUser> top3) {
    AppUser? first = top3.isNotEmpty ? top3[0] : null;
    AppUser? second = top3.length > 1 ? top3[1] : null;
    AppUser? third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver)
          if (second != null)
            Expanded(
              child: _buildPodiumStep(
                player: second,
                rank: 2,
                height: 120,
                color: const Color(0xFFC0C0C0),
                crown: '🥈',
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 8),

          // 1st Place (Gold)
          if (first != null)
            Expanded(
              child: _buildPodiumStep(
                player: first,
                rank: 1,
                height: 155,
                color: ThemeConfig.goldAccent,
                crown: '👑',
                isChampion: true,
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 8),

          // 3rd Place (Bronze)
          if (third != null)
            Expanded(
              child: _buildPodiumStep(
                player: third,
                rank: 3,
                height: 100,
                color: const Color(0xFFCD7F32),
                crown: '🥉',
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required AppUser player,
    required int rank,
    required double height,
    required Color color,
    required String crown,
    bool isChampion = false,
  }) {
    final scoreStr = _getScoreValue(player);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown / Avatar
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isChampion ? 2.5 : 1.8),
                boxShadow: isChampion
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: UserAvatar(user: player, radius: isChampion ? 32 : 26),
            ),
            Positioned(
              top: -16,
              child: Text(crown, style: TextStyle(fontSize: isChampion ? 22 : 18)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Name
        Text(
          player.displayName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isChampion ? FontWeight.bold : FontWeight.w600,
            fontSize: isChampion ? 13 : 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          scoreStr,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isChampion ? 13 : 11,
          ),
        ),
        const SizedBox(height: 6),
        // Pedestal base
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.35),
                color.withOpacity(0.08),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '#$rank',
            style: TextStyle(
              color: color,
              fontSize: isChampion ? 24 : 18,
              fontWeight: FontWeight.bold,
              fontFamily: ThemeConfig.fontHeading,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerRow(AppUser player, int rank, bool isMe) {
    final scoreStr = _getScoreValue(player);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe 
            ? ThemeConfig.goldAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe 
              ? ThemeConfig.goldAccent.withOpacity(0.5) 
              : Colors.white.withOpacity(0.08),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isMe ? ThemeConfig.goldAccent : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(user: player, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: ThemeConfig.goldAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'you_label'.tr(args: ['']),
                          style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (player.username != null)
                  Text(
                    '@${player.username}',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                scoreStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(player.winRate * 100).toStringAsFixed(0)}% Win',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyUserRank(AppUser currentUser) {
    final scoreStr = _getScoreValue(currentUser);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        border: Border(
          top: BorderSide(color: ThemeConfig.goldAccent.withOpacity(0.4), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            UserAvatar(user: currentUser, radius: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'your_rank'.tr(),
                    style: const TextStyle(
                      color: ThemeConfig.goldAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentUser.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: ThemeConfig.goldAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.5)),
              ),
              child: Text(
                scoreStr,
                style: const TextStyle(
                  color: ThemeConfig.goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getScoreValue(AppUser player) {
    switch (_selectedCategory) {
      case LeaderboardCategory.stars:
        return '${player.points} ⭐';
      case LeaderboardCategory.wins:
        return '${player.wins} 🏆';
      case LeaderboardCategory.bestScore:
        return '${player.bestScore} 🎯';
    }
  }
}
