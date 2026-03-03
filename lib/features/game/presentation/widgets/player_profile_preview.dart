import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/providers/game_providers.dart';
import '../../../../core/theme/theme_config.dart';

class PlayerProfilePreview extends ConsumerWidget {
  final AppUser user;

  const PlayerProfilePreview({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final userAsync = ref.watch(userProfileProvider(user.uid));

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: userAsync.when(
            data: (fullUser) {
              final displayUser = fullUser ?? user;
              final isMe = currentUser?.uid == displayUser.uid;
              final isFriend = currentUser?.friends.contains(displayUser.uid) ?? false;
              final isIncoming = currentUser?.pendingFriendRequests.contains(displayUser.uid) ?? false;
              final isHandled = isFriend || isIncoming;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar & Level
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: ThemeConfig.primaryTeal.withOpacity(0.1),
                        backgroundImage: displayUser.avatarUrl != null
                            ? (displayUser.avatarUrl!.startsWith('assets/')
                                ? AssetImage(displayUser.avatarUrl!) as ImageProvider
                                : NetworkImage(displayUser.avatarUrl!))
                            : null,
                        child: displayUser.avatarUrl == null
                            ? Text(
                                displayUser.displayName.isNotEmpty ? displayUser.displayName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeConfig.goldAccent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                        ),
                        child: Text(
                          'level'.tr(args: [displayUser.level.toString()]),
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    displayUser.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: ThemeConfig.fontHeading,
                    ),
                  ),
                  Text(
                    isMe ? 'you'.tr() : (displayUser.isAdmin ? 'Admin' : 'Player'),
                    style: TextStyle(color: ThemeConfig.primaryTeal.withOpacity(0.7), fontSize: 12),
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('win_rate'.tr(), '${(displayUser.winRate * 100).toStringAsFixed(0)}%'),
                      _buildStat('games_played'.tr(), displayUser.gamesPlayed.toString()),
                      _buildStat('points'.tr(), displayUser.points.toString()),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Actions
                  if (!isMe && currentUser != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isHandled ? Colors.white10 : ThemeConfig.primaryTeal,
                          foregroundColor: isHandled ? Colors.white54 : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isHandled 
                            ? null 
                            : () async {
                              await ref.read(multiplayerSyncServiceProvider).sendFriendRequest(currentUser.uid, displayUser.uid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('friend_request_sent'.tr())),
                                );
                                Navigator.pop(context);
                              }
                            },
                        icon: Icon(isFriend ? Icons.check : (isIncoming ? Icons.mail : Icons.person_add_alt_1_rounded)),
                        label: Text(
                          isFriend ? 'Friend' : (isIncoming ? 'requests_tab'.tr() : 'add_friend'.tr()),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('close'.tr(), style: const TextStyle(color: Colors.white38)),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: ThemeConfig.primaryTeal)),
            ),
            error: (err, _) => Center(child: Text('error_loading_profile'.tr(), style: const TextStyle(color: Colors.redAccent))),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
