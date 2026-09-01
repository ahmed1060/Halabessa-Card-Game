import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => AppUser.fromJson(doc.data(), doc.id)).toList();
  });
});

class AdminUserManagementScreen extends ConsumerWidget {
  const AdminUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('manage_users'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: usersAsync.when(
        data: (users) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserTile(context, ref, user);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: ThemeConfig.goldAccent)),
        error: (err, stack) => Center(child: Text('error_prefix'.tr(args: [err.toString()]), style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, WidgetRef ref, AppUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: user.isAdmin ? ThemeConfig.goldAccent.withOpacity(0.2) : Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null
              ? (user.avatarUrl!.startsWith('assets/')
                  ? AssetImage(user.avatarUrl!) as ImageProvider
                  : NetworkImage(user.avatarUrl!))
              : const AssetImage('assets/images/avatars/avatar1.png') as ImageProvider,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isAdmin)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ThemeConfig.goldAccent, borderRadius: BorderRadius.circular(4)),
                child: Text('admin_badge'.tr(), style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          '${user.points} ${'stars'.tr()} • ${'rank_label'.tr(args: [user.rank.toString()])}', 
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onSelected: (value) => _handleAction(context, ref, user, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'points',
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline, color: ThemeConfig.goldAccent),
                title: Text('edit_points'.tr()),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'admin',
              child: ListTile(
                leading: Icon(user.isAdmin ? Icons.remove_moderator : Icons.add_moderator, color: Colors.teal),
                title: Text(user.isAdmin ? 'remove_admin'.tr() : 'make_admin'.tr()),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, AppUser user, String action) async {
    if (action == 'admin') {
      // Routed through a Cloud Function: firestore.rules now rejects any
      // direct client write to isAdmin (it's a mirror of the Firebase Auth
      // custom claim, and only the Admin SDK may set either). See HAL-08.
      try {
        await FirebaseFunctions.instance.httpsCallable('setUserAdminClaim').call({
          'targetUid': user.uid,
          'isAdmin': !user.isAdmin,
        });
      } on FirebaseFunctionsException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
        }
      }
    } else if (action == 'points') {
      _showPointsEditor(context, user);
    }
  }

  void _showPointsEditor(BuildContext context, AppUser user) {
    final controller = TextEditingController(text: user.points.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeConfig.darkBg,
        title: Text('edit_points'.tr(), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'stars'.tr(),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              final newPoints = int.tryParse(controller.text) ?? user.points;
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'points': newPoints,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }
}
