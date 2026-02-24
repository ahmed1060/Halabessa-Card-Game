import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        title: const Text('Change Email Address'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'New Email Address'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
                    const SnackBar(content: Text('Firebase has sent a confirmation link to your new address to verify the change.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e\n(You may need to log out and log back in first)')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in.')),
      );
    }

    final isAnonymous = user.uid.startsWith('guest_') || user.email.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
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
              isAnonymous ? 'Guest Account' : user.email,
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
                title: Text(user.isEmailVerified ? 'Email Verified' : 'Email Not Verified'),
                trailing: user.isEmailVerified 
                    ? null 
                    : (_isLoading 
                        ? const CircularProgressIndicator() 
                        : TextButton(
                            onPressed: _sendVerificationEmail,
                            child: const Text('Send Link'),
                          )),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Change Email Address'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _showChangeEmailDialog,
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
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
