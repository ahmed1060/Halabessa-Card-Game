import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/features/game/domain/models/room_summary.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/data/repositories/multiplayer_sync_service.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/utils/error_handler.dart';

class PublicRoomsList extends ConsumerWidget {
  const PublicRoomsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(multiplayerSyncServiceProvider);
    final currentUser = ref.watch(currentUserProvider);
    return StreamBuilder<List<RoomSummary>>(
      stream: syncService.watchPublicMatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'no_public_matches'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.videogame_asset, color: Colors.white),
                ),
                title: Text(
                  'join_matching_mode'.tr(args: [match.mode.name.toUpperCase()]),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'room_players_info'.tr(args: [
                    '${match.playerIds.where((id) => !id.startsWith('waiting_')).length}/4', 
                    match.id
                  ]),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.visibility_outlined, color: ThemeConfig.goldAccent),
                      onPressed: () {
                        ref.read(matchStateProvider.notifier).spectateMatch(match.id);
                        Navigator.pushNamed(context, '/game');
                      },
                      tooltip: 'spectate'.tr(),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final bool isFull = !match.playerIds.any((id) => id.startsWith('waiting_'));
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (currentUser?.isAdmin == true)
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                onPressed: () => _confirmDelete(context, syncService, match.id),
                                tooltip: 'delete_room'.tr(),
                              ),
                            if (currentUser?.isAdmin == true) const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: isFull ? null : () async {
                                if (currentUser != null) {
                                  try {
                                    await ref.read(matchStateProvider.notifier).joinMatch(
                                      match.id, 
                                      currentUser.uid, 
                                      currentUser.displayName
                                    );
                                    if (context.mounted) {
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFull ? Colors.grey.withOpacity(0.3) : Colors.teal,
                              ),
                              child: Text(isFull ? 'full'.tr() : 'join'.tr()),
                            ),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, MultiplayerSyncService syncService, String matchId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text('delete_room'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text('delete_room_confirm'.tr(args: [matchId]), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              syncService.deleteMatch(matchId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }
}
