import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../game/domain/providers/game_providers.dart';
import '../../../game/domain/models/match_state.dart';
import '../widgets/public_rooms_list.dart';
import '../../auth/presentation/widgets/social_overlay.dart' as social_ui;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
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
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.casino, size: 100, color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                'welcome_player'.tr(args: [user?.displayName ?? "Player"]),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('points_and_rank'.tr(args: [user?.points.toString() ?? '0', user?.rank.toString() ?? '0'])),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _showCreateRoomDialog(context, ref, user?.uid ?? 'unknown', user?.displayName ?? 'Player');
                },
                icon: const Icon(Icons.add),
                label: Text('create_game_room'.tr()),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                   _showJoinRoomDialog(context, ref, user?.uid ?? 'unknown', user?.displayName ?? 'Player');
                },
                icon: const Icon(Icons.group_add),
                label: Text('join_game_room'.tr()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 48),
              const Divider(color: Colors.white24),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'available_matches'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              PublicRoomsList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref, String playerId, String displayName) {
    int selectedTimerSeconds = 10; // Default is now 10. 0 represents Infinity
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return AlertDialog(
              title: Text('create_room'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                         timerDurationSeconds: selectedTimerSeconds,
                         isPublic: isPublic,
                      );
                      Navigator.pushNamed(context, '/game');
                    } catch (e) {
                      debugPrint('Match init error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase Warning: $e (Continuing locally...)')));
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
                         timerDurationSeconds: selectedTimerSeconds,
                         isPublic: isPublic,
                      );
                      Navigator.pushNamed(context, '/game');
                    } catch (e) {
                      debugPrint('Match init error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase Warning: $e (Continuing locally...)')));
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
               onPressed: () {
                 final roomId = roomController.text.trim().toUpperCase();
                 if (roomId.isNotEmpty) {
                    Navigator.pop(dialogContext);
                    ref.read(matchStateProvider.notifier).joinMatch(roomId, playerId, displayName);
                    Navigator.pushNamed(context, '/game');
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
