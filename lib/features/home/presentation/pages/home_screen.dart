import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';
import 'package:halabessa/features/auth/presentation/widgets/social_overlay.dart' as social_ui;
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/home/presentation/widgets/overlays/create_room_overlay.dart';
import 'package:halabessa/features/home/presentation/widgets/overlays/join_room_overlay.dart';

import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/services/asset_preloader_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Initiate Asset Preloading & Background Music
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetPreloaderServiceProvider).preloadAll(context);
      ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('app_title'.tr(), style: const TextStyle(fontFamily: ThemeConfig.fontHeading, letterSpacing: 2)),
        actions: [
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 120),
            // User Profile Section
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                          'points_and_rank'.tr(args: [user.points.toString(), user.rank.toString()]),
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 48),
            
            // Main Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMainButton(
                      context,
                      label: 'create_room'.tr(),
                      icon: Icons.add_box_outlined,
                      color: ThemeConfig.primaryTeal,
                      onTap: () => _showCreateRoomDialog(context, ref, user?.uid ?? '', user?.displayName ?? ''),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMainButton(
                      context,
                      label: 'join_room'.tr(),
                      icon: Icons.login_outlined,
                      color: ThemeConfig.goldAccent,
                      onTap: () => _showJoinRoomDialog(context, ref, user?.uid ?? '', user?.displayName ?? ''),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            // Public Matches List
            Expanded(
              child: Container(
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
                    const Expanded(child: PublicRoomsList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref, String playerId, String displayName) {
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

  void _showJoinRoomDialog(BuildContext context, WidgetRef ref, String playerId, String displayName) {
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
