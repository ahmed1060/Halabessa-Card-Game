import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  void _sendVerificationEmail() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('verification_sent'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_general'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('change_email_address'.tr()),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(labelText: 'new_email_address'.tr()),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = emailController.text.trim();
              if (newEmail.isEmpty) return;
              Navigator.pop(dialogContext);
              
              setState(() => _isLoading = true);
              try {
                await ref.read(authRepositoryProvider).updateEmail(newEmail);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('email_change_confirm'.tr())),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('error_general'.tr(args: ['$e\n(You may need to log out and log back in first)']))),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text('update'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        body: Center(child: Text('not_logged_in'.tr())),
      );
    }

    final isAnonymous = user.uid.startsWith('guest_') || user.email.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('player_profile'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal.shade200,
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAnonymous ? 'guest_account'.tr() : user.email,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            if (!isAnonymous) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  user.isEmailVerified ? Icons.check_circle : Icons.warning,
                  color: user.isEmailVerified ? Colors.green : Colors.orange,
                ),
                title: Text(user.isEmailVerified ? 'email_verified'.tr() : 'email_not_verified'.tr()),
                trailing: user.isEmailVerified 
                    ? null 
                    : (_isLoading 
                        ? const CircularProgressIndicator() 
                        : TextButton(
                            onPressed: _sendVerificationEmail,
                            child: Text('send_link'.tr()),
                          )),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.email),
                title: Text('change_email_address'.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _showChangeEmailDialog,
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('log_out'.tr(), style: const TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(authRepositoryProvider).signOut();
                Navigator.pop(context); // Go back home/login
              },
            ),
          ],
        ),
      ),
    );
  }
}
