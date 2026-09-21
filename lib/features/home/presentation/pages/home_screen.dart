import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';
import 'package:halabessa/features/auth/presentation/widgets/social_overlay.dart' as social_ui;
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/home/presentation/widgets/overlays/create_room_overlay.dart';
import 'package:halabessa/features/home/presentation/widgets/overlays/join_room_overlay.dart';

import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/services/asset_preloader_service.dart';

import 'package:halabessa/features/auth/presentation/widgets/username_onboarding_overlay.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';
import 'package:halabessa/features/home/presentation/widgets/daily_streak_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedOnboarding = false;
  bool _isQuickMatching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');

      // Check onboarding once
      final user = ref.read(currentUserProvider);
      if (user != null && user.username == null && !_hasCheckedOnboarding) {
        _hasCheckedOnboarding = true;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) => const UsernameOnboardingOverlay(),
        );
      }

      _checkDailyStreakReward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Secondary check if user state updates asynchronously
    if (user != null && user.username == null && !_hasCheckedOnboarding) {
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
      backgroundColor: const Color(0xFF0D1B2A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('app_title'.tr(), style: const TextStyle(fontFamily: ThemeConfig.fontHeading, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: ThemeConfig.goldAccent),
            onPressed: () async {
              final status = await DailyStreakService.checkStatus();
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => DailyStreakDialog(status: status),
                );
              }
            },
            tooltip: 'daily_reward_title'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: ThemeConfig.goldAccent),
            onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
            tooltip: 'leaderboard_title'.tr(),
          ),
          IconButton(
            icon: Icon(Icons.shopping_bag_outlined, color: ThemeConfig.goldAccent),
            onPressed: () => Navigator.pushNamed(context, '/store'),
            tooltip: 'store'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Colors.white70),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const social_ui.SocialOverlay(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const SettingsOverlay(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
        child: Container(
          decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 120),
              // User Profile Section
              if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Row(
                      children: [
                        UserAvatar(radius: 30, user: user),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'welcome_player'.tr(args: [user.displayName]),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              user.isAdmin 
                                ? 'status_admin'.tr()
                                : 'points_and_rank'.tr(args: [user.points.toString(), user.rank.toString()]),
                              style: TextStyle(color: ThemeConfig.goldAccent.withOpacity(0.9), fontSize: 12, fontWeight: user.isAdmin ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // 1. Quick Match Hero Card (Golden, Pulsing, 1-Tap)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildQuickMatchHero(context, user),
              ),

              const SizedBox(height: 14),

              // 2. Secondary Row: Solo Practice vs Bots & Create Custom Room
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryActionCard(
                        context,
                        title: 'practice_bots'.tr(),
                        subtitle: 'practice_bots_desc'.tr(),
                        icon: Icons.smart_toy_outlined,
                        gradient: const [Color(0xFF0F3443), Color(0xFF1E5B4B)],
                        accentColor: const Color(0xFF34E89E),
                        onTap: () => _startOfflinePractice(context, user),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecondaryActionCard(
                        context,
                        title: 'create_room'.tr(),
                        subtitle: 'room_code'.tr(),
                        icon: Icons.add_circle_outline_rounded,
                        gradient: const [Color(0xFF1B263B), Color(0xFF283854)],
                        accentColor: ThemeConfig.primaryTeal,
                        onTap: () => _showCreateRoomDialog(context, user?.uid ?? '', user?.displayName ?? ''),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Join with Code Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildJoinCodeBar(context, user),
              ),

              const SizedBox(height: 28),
              
              // Public Matches List
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'available_matches'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const PublicRoomsList(),
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

  Widget _buildQuickMatchHero(BuildContext context, dynamic user) {
    return GestureDetector(
      key: const ValueKey('play_now_btn'),
      onTap: () => _handleQuickMatch(context, user),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4AF37), Color(0xFF996515), Color(0xFF593E10)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: ThemeConfig.goldAccent.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                Icons.bolt_rounded,
                size: 110,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: _isQuickMatching
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.flash_on_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'quick_match'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isQuickMatching ? 'searching_match'.tr() : 'quick_match_desc'.tr(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accentColor, size: 26),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.35), size: 13),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCodeBar(BuildContext context, dynamic user) {
    return GestureDetector(
      onTap: () => _showJoinRoomDialog(context, user?.uid ?? '', user?.displayName ?? ''),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.pin_outlined, color: ThemeConfig.goldAccent.withOpacity(0.9), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'join_room'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              'enter_code'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.35), size: 13),
          ],
        ),
      ),
    );
  }

  void _handleQuickMatch(BuildContext context, dynamic user) async {
    if (_isQuickMatching) return;
    setState(() => _isQuickMatching = true);
    
    try {
      await ref.read(matchStateProvider.notifier).quickMatch(
        user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
        user?.displayName ?? 'Player',
      );
      if (mounted) {
        Navigator.pushNamed(context, '/game');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isQuickMatching = false);
      }
    }
  }

  void _startOfflinePractice(BuildContext context, dynamic user) {
    ref.read(matchStateProvider.notifier).startOfflinePracticeMatch(
      user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
      user?.displayName ?? 'Player',
    );
    Navigator.pushNamed(context, '/game');
  }

  void _checkDailyStreakReward() async {
    final status = await DailyStreakService.checkStatus();
    if (status.isClaimableToday && mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => DailyStreakDialog(status: status),
      );
    }
  }

  void _showCreateRoomDialog(BuildContext context, String playerId, String displayName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateRoomOverlay(
        playerId: playerId,
        displayName: displayName,
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context, String playerId, String displayName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JoinRoomOverlay(
        playerId: playerId,
        displayName: displayName,
      ),
    );
  }
}
