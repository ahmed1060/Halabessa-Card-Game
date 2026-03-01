import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/home/presentation/widgets/public_rooms_list.dart';
import 'package:halabessa/features/auth/presentation/widgets/social_overlay.dart' as social_ui;
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/core/widgets/user_avatar.dart';
import 'package:halabessa/core/theme/theme_config.dart';

import 'package:halabessa/core/utils/error_handler.dart';
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
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const social_ui.SocialOverlay(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const SettingsOverlay(),
              );
            },
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: UserAvatar(
                user: user,
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0x3300E5FF)],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'welcome_player'.tr(args: [user?.displayName ?? 'player_default_name'.tr()]),
                    style: const TextStyle(fontFamily: ThemeConfig.fontHeading, fontSize: 28, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'points_and_rank'.tr(args: [user?.points.toString() ?? '0', user?.rank.toString() ?? '0']),
                    style: const TextStyle(fontFamily: ThemeConfig.fontBody, color: ThemeConfig.goldAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  _buildMenuButton(
                    context, 
                    label: 'create_game_room'.tr(), 
                    icon: Icons.add_circle_outline,
                    onTap: () => _showCreateRoomDialog(context, ref, user?.uid ?? 'unknown', user?.displayName ?? 'player_default_name'.tr()),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 16),
                  _buildMenuButton(
                    context, 
                    label: 'join_game_room'.tr(), 
                    icon: Icons.group_add_outlined,
                    onTap: () => _showJoinRoomDialog(context, ref, user?.uid ?? 'unknown', user?.displayName ?? 'player_default_name'.tr()),
                    isPrimary: false,
                  ),
                  const SizedBox(height: 16),
                  _buildMenuButton(
                    context, 
                    label: 'store_label'.tr(), 
                    icon: Icons.shopping_bag_outlined,
                    onTap: () => Navigator.pushNamed(context, '/store'),
                    isPrimary: false,
                    accentColor: ThemeConfig.goldAccent,
                  ),
                  const SizedBox(height: 48),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'available_matches'.tr(),
                      style: const TextStyle(fontFamily: ThemeConfig.fontHeading, color: Colors.white, fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PublicRoomsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    Color? accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? (accentColor ?? ThemeConfig.primaryTeal).withOpacity(0.8) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? (accentColor ?? ThemeConfig.goldAccent).withOpacity(0.5) : Colors.white12,
          width: 1,
        ),
        boxShadow: [
          if (isPrimary)
            BoxShadow(
              color: (accentColor ?? ThemeConfig.primaryTeal).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              children: [
                Icon(icon, color: isPrimary ? Colors.white : (accentColor ?? Colors.white70), size: 28),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: ThemeConfig.fontHeading,
                    fontSize: 18,
                    color: isPrimary ? Colors.white : Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: isPrimary ? Colors.white54 : Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref, String playerId, String displayName) {
    int selectedTimerSeconds = 10; // Default is now 10. 0 represents Infinity
    int selectedTargetScore = 41;
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return AlertDialog(
              title: Text('create_room'.tr()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('select_target_score'.tr()),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: selectedTargetScore,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: 21, child: Text('target_score_21'.tr())),
                        DropdownMenuItem(value: 41, child: Text('target_score_41'.tr())),
                        DropdownMenuItem(value: 61, child: Text('target_score_61'.tr())),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() { selectedTargetScore = val; });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('select_timer'.tr()),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: selectedTimerSeconds,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: 5, child: Text('5_seconds'.tr())),
                        DropdownMenuItem(value: 10, child: Text('10_seconds_default'.tr())),
                        DropdownMenuItem(value: 15, child: Text('15_seconds'.tr())),
                        DropdownMenuItem(value: 0, child: Text('no_timer'.tr())),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() { selectedTimerSeconds = val; });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('select_game_mode'.tr()),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('public_room'.tr()),
                      subtitle: Text('public_room_desc'.tr()),
                      value: isPublic,
                      onChanged: (val) {
                        setState(() { isPublic = val; });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      ref.read(matchStateProvider.notifier).initializeMatch(
                         playerId,
                         displayName,
                         GameMode.classic,
                         maxPoints: selectedTargetScore,
                         timerDurationSeconds: selectedTimerSeconds,
                         isPublic: isPublic,
                      );
                      Navigator.pushNamed(context, '/game');
                    } catch (e) {
                      debugPrint('Match init error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))));
                        Navigator.pushNamed(context, '/game');
                      }
                    }
                  },
                  child: Text('classic_mode'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      ref.read(matchStateProvider.notifier).initializeMatch(
                         playerId,
                         displayName,
                         GameMode.tafweet,
                         maxPoints: selectedTargetScore,
                         timerDurationSeconds: selectedTimerSeconds,
                         isPublic: isPublic,
                      );
                      Navigator.pushNamed(context, '/game');
                    } catch (e) {
                      debugPrint('Match init error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))));
                        Navigator.pushNamed(context, '/game');
                      }
                    }
                  },
                  child: Text('tafweet_mode'.tr()),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showJoinRoomDialog(BuildContext context, WidgetRef ref, String playerId, String displayName) {
    final TextEditingController roomController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('join_room'.tr()),
          content: TextField(
            controller: roomController,
            decoration: InputDecoration(labelText: 'room_code'.tr()),
          ),
          actions: [
             TextButton(
               onPressed: () => Navigator.pop(dialogContext),
               child: Text('cancel'.tr()),
             ),
              ElevatedButton(
                onPressed: () async {
                  final roomId = roomController.text.trim().toUpperCase();
                  if (roomId.isNotEmpty) {
                    try {
                      await ref.read(matchStateProvider.notifier).joinMatch(roomId, playerId, displayName);
                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        Navigator.pushNamed(context, '/game');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
                        );
                      }
                    }
                  }
                },
                child: Text('join'.tr()),
              ),
          ],
        );
      }
    );
  }
}
