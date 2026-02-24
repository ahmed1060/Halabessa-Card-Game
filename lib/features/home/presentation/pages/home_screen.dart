import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../game/domain/providers/game_providers.dart';
import '../../../game/domain/models/match_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('7alabessa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: Center(
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
                _showCreateRoomDialog(context, ref, user?.uid ?? 'unknown');
              },
              icon: const Icon(Icons.add),
              label: Text('create_game_room'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                 _showJoinRoomDialog(context, ref, user?.uid ?? 'unknown');
              },
              icon: const Icon(Icons.group_add),
              label: Text('join_game_room'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref, String playerId) {
    int selectedTimerSeconds = 10; // Default is now 10. 0 represents Infinity

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
                         [playerId], // Only instantiate the creator
                         GameMode.classic,
                         timerDurationSeconds: selectedTimerSeconds,
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
                         [playerId], // Only instantiate the creator
                         GameMode.tafweet,
                         timerDurationSeconds: selectedTimerSeconds,
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

  void _showJoinRoomDialog(BuildContext context, WidgetRef ref, String playerId) {
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
                    ref.read(matchStateProvider.notifier).joinMatch(roomId, playerId);
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
