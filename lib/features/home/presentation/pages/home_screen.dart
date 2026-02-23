import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              'Welcome, \${user?.displayName ?? "Player"}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Points: \${user?.points ?? 0} | Rank: \${user?.rank ?? 0}'),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _showCreateRoomDialog(context, ref, user?.uid ?? 'unknown');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Game Room'),
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
              label: const Text('Join Game Room'),
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Room'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('Select turn timer duration:'),
                   const SizedBox(height: 8),
                   DropdownButton<int>(
                     value: selectedTimerSeconds,
                     isExpanded: true,
                     items: const [
                        DropdownMenuItem(value: 5, child: Text("5 Seconds")),
                        DropdownMenuItem(value: 10, child: Text("10 Seconds (Default)")),
                        DropdownMenuItem(value: 15, child: Text("15 Seconds")),
                        DropdownMenuItem(value: 0, child: Text("Infinity / No Timer")),
                     ],
                     onChanged: (val) {
                       if (val != null) {
                         setState(() { selectedTimerSeconds = val; });
                       }
                     },
                   ),
                   const SizedBox(height: 16),
                   const Text('Select game mode to create match:'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(matchStateProvider.notifier).initializeMatch(
                       [playerId, 'bot1', 'bot2', 'bot3'], // Placeholder for 4 players
                       GameMode.classic,
                       timerDurationSeconds: selectedTimerSeconds,
                    );
                    Navigator.pushNamed(context, '/game');
                  },
                  child: const Text('Classic Mode'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(matchStateProvider.notifier).initializeMatch(
                       [playerId, 'bot1', 'bot2', 'bot3'], // Placeholder
                       GameMode.tafweet,
                       timerDurationSeconds: selectedTimerSeconds,
                    );
                    Navigator.pushNamed(context, '/game');
                  },
                  child: const Text('Tafweet Mode'),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Room'),
          content: TextField(
            controller: roomController,
            decoration: const InputDecoration(labelText: 'Room ID'),
          ),
          actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text('Cancel'),
             ),
             ElevatedButton(
               onPressed: () {
                 final roomId = roomController.text.trim();
                 if (roomId.isNotEmpty) {
                    Navigator.pop(context);
                    ref.read(matchStateProvider.notifier).bindToMatch(roomId);
                    Navigator.pushNamed(context, '/game');
                 }
               },
               child: const Text('Join'),
             ),
          ],
        );
      }
    );
  }
}
