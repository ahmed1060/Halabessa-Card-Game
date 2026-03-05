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
  final Set<String> _actionLoadingUserIds = {}; // Tracks loading for Add/Accept/Reject

  void _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await ref.read(multiplayerSyncServiceProvider).searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _performSearch: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.group_rounded, color: Colors.tealAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'friends_list'.tr(), 
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // TabBar
            TabBar(
              indicatorColor: Colors.tealAccent,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.white38,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'friends_tab'.tr()),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('requests_tab'.tr()),
                      if (currentUser.pendingFriendRequests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${currentUser.pendingFriendRequests.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(text: 'search_tab'.tr()),
              ],
            ),
            const Divider(color: Colors.white10, height: 1),
            // TabView
            Expanded(
              child: TabBarView(
                children: [
                  _buildFriendsTab(currentUser, scrollController),
                  _buildRequestsTab(currentUser, scrollController),
                  _buildSearchTab(currentUser, scrollController),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFriendsTab(AppUser currentUser, ScrollController scrollController) {
    if (currentUser.friends.isEmpty && currentUser.friendInvites.isEmpty) {
      return _buildEmptyState(Icons.person_outline, 'no_friends_yet'.tr());
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Game Invitations Section
        if (currentUser.friendInvites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 4),
            child: Row(
              children: [
                const Icon(Icons.sports_esports, color: Colors.orangeAccent, size: 18),
                const SizedBox(width: 8),
                Text('invitations'.tr().toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ],
            ),
          ),
          ...currentUser.friendInvites.entries.map((invite) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orangeAccent.withOpacity(0.1), Colors.transparent]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.mail, color: Colors.black87)),
              title: Text('invite_from'.tr(args: [invite.value]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('join'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                   ref.read(matchStateProvider.notifier).joinMatch(invite.key, currentUser.uid, currentUser.displayName);
                   Navigator.pop(context);
                   Navigator.pushNamed(context, '/game');
                },
              ),
            ),
          )),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
        ],

        // Friends List Section
        if (currentUser.friends.isNotEmpty)
          ...currentUser.friends.map((friendUid) => ref.watch(userProfileProvider(friendUid)).when(
            data: (user) {
              if (user == null) {
                return _buildErrorState('user_not_found'.tr());
              }
              return _buildUserTile(user, isFriend: true);
            },
            loading: () => const SizedBox(height: 72, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)))),
            error: (e, __) => _buildErrorState(e.toString()),
          )),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('error_prefix'.tr(args: [error]), style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AppUser currentUser, ScrollController scrollController) {
    if (currentUser.pendingFriendRequests.isEmpty) {
        return _buildEmptyState(Icons.mail_outline_rounded, 'no_friend_requests'.tr());
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: currentUser.pendingFriendRequests.length,
      itemBuilder: (context, index) {
        final reqUid = currentUser.pendingFriendRequests[index];
        return ref.watch(userProfileProvider(reqUid)).when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return _buildUserTile(user, isRequest: true, myUid: currentUser.uid);
          },
          loading: () => const SizedBox(height: 72, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSearchTab(AppUser currentUser, ScrollController scrollController) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'search_users_hint'.tr(), // Example: "Search by @username"
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.tealAccent),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: _performSearch,
          ),
        ),
        if (_isSearching)
          const Padding(padding: EdgeInsets.only(top: 32), child: CircularProgressIndicator(color: Colors.tealAccent))
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
           _buildEmptyState(Icons.search_off_rounded, 'no_results'.tr())
        else
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                if (user.uid == currentUser.uid) return const SizedBox.shrink();
                
                final isFriend = currentUser.friends.contains(user.uid);
                final isIncoming = currentUser.pendingFriendRequests.contains(user.uid);
                final isOutgoing = currentUser.sentFriendRequests.contains(user.uid);
                
                return _buildUserTile(user, isFriend: isFriend, isPending: isIncoming || isOutgoing, isSearch: true, myUid: currentUser.uid);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildUserTile(AppUser user, {bool isFriend = false, bool isRequest = false, bool isPending = false, bool isSearch = false, String? myUid}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
             padding: const EdgeInsets.all(2),
             decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.tealAccent.withOpacity(0.2))),
             child: CircleAvatar(
               radius: 24,
               backgroundColor: Colors.teal.withOpacity(0.2),
               backgroundImage: user.avatarUrl != null
                 ? (user.avatarUrl!.startsWith('assets/') ? AssetImage(user.avatarUrl!) as ImageProvider : NetworkImage(user.avatarUrl!))
                 : null,
               child: user.avatarUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
             ),
        ),
        title: Row(
          children: [
            Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            if (user.username != null) ...[
              const SizedBox(width: 8),
              Text('@${user.username}', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.w400)),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Icon(Icons.stars_rounded, color: Colors.amber.shade300, size: 14),
            const SizedBox(width: 4),
            Text('level_label'.tr(args: [user.level.toString()]), style: TextStyle(color: Colors.amber.shade100.withOpacity(0.7), fontSize: 13)),
          ],
        ),
        trailing: _buildActions(user, isFriend, isRequest, isPending, isSearch, myUid),
      ),
    );
  }

  Widget _buildActions(AppUser user, bool isFriend, bool isRequest, bool isPending, bool isSearch, String? myUid) {
     if (_actionLoadingUserIds.contains(user.uid)) {
       return const SizedBox(
         width: 24,
         height: 24,
         child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
       );
     }

     if (isFriend) {
       return const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28);
     }
     if (isRequest && myUid != null) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           IconButton(
             icon: const Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
             onPressed: () async {
                setState(() => _actionLoadingUserIds.add(user.uid));
                try {
                  await ref.read(multiplayerSyncServiceProvider).acceptFriendRequest(myUid, user.uid);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('friend_request_accepted'.tr())));
                } finally {
                  if (mounted) setState(() => _actionLoadingUserIds.remove(user.uid));
                }
             },
           ),
           IconButton(
             icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
             onPressed: () async {
                setState(() => _actionLoadingUserIds.add(user.uid));
                try {
                  await ref.read(multiplayerSyncServiceProvider).rejectFriendRequest(myUid, user.uid);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('friend_request_rejected'.tr())));
                } finally {
                  if (mounted) setState(() => _actionLoadingUserIds.remove(user.uid));
                }
             },
           ),
         ],
       );
     }
     if (isSearch && myUid != null) {
       if (isPending) {
         return Text('requests_tab'.tr(), style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold));
       }
       return IconButton(
         icon: const Icon(Icons.person_add_rounded, color: Colors.tealAccent),
         onPressed: () async {
           setState(() => _actionLoadingUserIds.add(user.uid));
           try {
             await ref.read(multiplayerSyncServiceProvider).sendFriendRequest(myUid, user.uid);
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('friend_request_sent'.tr())));
           } finally {
             if (mounted) setState(() => _actionLoadingUserIds.remove(user.uid));
           }
         },
       );
     }
     return const SizedBox.shrink();
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16)),
        ],
      ),
    );
  }
}
