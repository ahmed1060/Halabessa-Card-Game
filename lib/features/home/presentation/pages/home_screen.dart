import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/core/widgets/lantern_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';
import 'package:halabessa/features/auth/presentation/widgets/social_overlay.dart'
    as social_ui;
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/features/home/presentation/widgets/overlays/create_room_overlay.dart';
import 'package:halabessa/features/home/presentation/widgets/room_entry_forms.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

import 'package:halabessa/core/services/multimedia_service.dart';

import 'package:halabessa/features/auth/presentation/widgets/username_onboarding_overlay.dart';
import 'package:halabessa/core/services/daily_streak_service.dart';
import 'package:halabessa/features/home/presentation/widgets/daily_streak_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isQuickMatching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');

      // Rewards and profile setup are opened by the player, never stacked on startup.
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: TableStyle.ink,
          title: user == null
              ? const Text('Halabessa')
              : Row(
                  children: [
                    UserAvatar(radius: 22, user: user),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TableStyle.label,
                      ),
                    ),
                  ],
                ),
          actions: [
            IconButton(
              tooltip: 'settings'.tr(),
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsOverlay(),
              ),
            ),
            IconButton(
              tooltip: 'player_profile'.tr(),
              icon: const Icon(Icons.person_rounded),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LanternWordmark(),
                    const SizedBox(height: 24),
                    _lobbyAction(
                      title: 'quick_match'.tr(),
                      subtitle:
                          (_isQuickMatching
                                  ? 'searching_match'
                                  : 'quick_match_desc')
                              .tr(),
                      icon: Icons.groups_rounded,
                      primary: true,
                      onTap: () => _handleQuickMatch(context, user),
                    ),
                    const SizedBox(height: 12),
                    _lobbyAction(
                      title: 'practice_bots'.tr(),
                      subtitle: 'practice_bots_desc'.tr(),
                      icon: Icons.person_rounded,
                      onTap: () => _startOfflinePractice(context, user),
                    ),
                    const SizedBox(height: 12),
                    _lobbyAction(
                      title: 'create_room'.tr(),
                      subtitle: 'room_code'.tr(),
                      icon: Icons.add_rounded,
                      onTap: () => _showCreateRoomDialog(
                        context,
                        user?.uid ?? '',
                        user?.displayName ?? '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: TableStyle.ink,
                      borderRadius: BorderRadius.circular(18),
                      child: ExpansionTile(
                        title: Text('join_room'.tr(), style: TableStyle.label),
                        leading: const Icon(
                          Icons.login_rounded,
                          color: TableStyle.ivory,
                        ),
                        childrenPadding: const EdgeInsets.all(12),
                        children: [_buildJoinCodeBar(context, user)],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _lobbyUtility(
                          'friends_tab'.tr(),
                          Icons.people_rounded,
                          () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const social_ui.SocialOverlay(),
                          ),
                        ),
                        _lobbyUtility(
                          'store'.tr(),
                          Icons.shopping_bag_rounded,
                          () => Navigator.pushNamed(context, '/store'),
                        ),
                        _lobbyUtility(
                          'leaderboard_title'.tr(),
                          Icons.emoji_events_rounded,
                          () => Navigator.pushNamed(context, '/leaderboard'),
                        ),
                        _lobbyUtility(
                          'daily_reward_title'.tr(),
                          Icons.card_giftcard_rounded,
                          () async {
                            final status =
                                await DailyStreakService.checkStatus();
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) =>
                                    DailyStreakDialog(status: status),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    if (user != null && (user.username?.isEmpty ?? true))
                      TextButton.icon(
                        icon: const Icon(Icons.alternate_email),
                        label: Text('setup_username_optional'.tr()),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const UsernameOnboardingOverlay(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TableStyle.ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'available_matches'.tr(),
                            style: TableStyle.label,
                          ),
                          const SizedBox(height: 12),
                          const PublicRoomsList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lobbyAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) => Material(
    color: primary ? TableStyle.mint : TableStyle.ink,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primary ? TableStyle.ink : TableStyle.mint,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: primary ? TableStyle.ink : TableStyle.ivory,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TableStyle.label.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primary ? TableStyle.ink : TableStyle.ivory,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TableStyle.detail.copyWith(
                      color: primary ? TableStyle.ink : TableStyle.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _lobbyUtility(String label, IconData icon, VoidCallback action) =>
      SizedBox(
        width: 120,
        child: OutlinedButton(
          onPressed: action,
          style: OutlinedButton.styleFrom(
            backgroundColor: TableStyle.ink,
            side: const BorderSide(color: TableStyle.mint),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Column(
            children: [
              Icon(icon, color: TableStyle.brass),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TableStyle.detail,
              ),
            ],
          ),
        ),
      );

  Widget _buildJoinCodeBar(BuildContext context, dynamic user) {
    return Material(
      color: TableStyle.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RoomJoinForm(
          text: (key) => key.tr(),
          onJoin: (code) => ref
              .read(matchStateProvider.notifier)
              .joinMatch(code, user?.uid ?? '', user?.displayName ?? ''),
          onJoined: () => Navigator.pushNamed(context, '/game'),
        ),
      ),
    );
  }

  void _handleQuickMatch(BuildContext context, dynamic user) async {
    if (_isQuickMatching) return;
    setState(() => _isQuickMatching = true);

    try {
      await ref
          .read(matchStateProvider.notifier)
          .quickMatch(
            user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
            user?.displayName ?? 'Player',
          );
      if (mounted) {
        Navigator.pushNamed(context, '/game');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'error'.tr()}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isQuickMatching = false);
      }
    }
  }

  void _startOfflinePractice(BuildContext context, dynamic user) {
    ref
        .read(matchStateProvider.notifier)
        .startOfflinePracticeMatch(
          user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
          user?.displayName ?? 'Player',
        );
    Navigator.pushNamed(context, '/game');
  }

  void _showCreateRoomDialog(
    BuildContext context,
    String playerId,
    String displayName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CreateRoomOverlay(playerId: playerId, displayName: displayName),
    );
  }
}
