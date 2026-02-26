import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../game/domain/providers/game_providers.dart';

class SocialOverlay extends ConsumerStatefulWidget {
  const SocialOverlay({super.key});

  @override
  ConsumerState<SocialOverlay> createState() => _SocialOverlayState();
}

class _SocialOverlayState extends ConsumerState<SocialOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    
    if (mounted) setState(() => _isSearching = true);
    final results = await ref.read(multiplayerSyncServiceProvider).searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Colors.teal),
              const SizedBox(width: 12),
              Text('friends_list'.tr(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'search_users'.tr(),
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _performSearch,
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  if (user.uid == currentUser.uid) return const SizedBox.shrink();
                  
                  final isFriend = currentUser.friends.contains(user.uid);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(user.displayName, style: const TextStyle(color: Colors.white)),
                    trailing: isFriend 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.person_add, color: Colors.teal),
                          onPressed: () {
                            ref.read(multiplayerSyncServiceProvider).addFriend(currentUser.uid, user.uid);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('friend_added'.tr())));
                          },
                        ),
                  );
                },
              ),
            ),
          const Divider(color: Colors.white24, height: 32),
          // Placeholder for Friends list / Invites
          if (currentUser.friendInvites.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('invitations'.tr(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            ...currentUser.friendInvites.entries.map((invite) => ListTile(
              title: Text('invite_from'.tr(args: [invite.value]), style: const TextStyle(color: Colors.white)),
              trailing: ElevatedButton(
                child: Text('join'.tr()),
                onPressed: () {
                   ref.read(matchStateProvider.notifier).joinMatch(invite.key, currentUser.uid, currentUser.displayName);
                   Navigator.pop(context); // Close overlay
                   Navigator.pushNamed(context, '/game');
                },
              ),
            )),
          ],
        ],
      ),
    );
  }
}
