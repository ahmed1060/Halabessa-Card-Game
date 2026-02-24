import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _guestNameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    try {
      if (_isLogin) {
        await authRepo.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await authRepo.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim().isEmpty ? 'New Player' : _nameController.text.trim(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInAnonymously() async {
    final guestName = _guestNameController.text.trim();
    if (guestName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a nickname first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    try {
      await authRepo.signInAnonymously(displayName: guestName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInWithSocial(Future<void> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      await signInMethod();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \$e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog(BuildContext context, WidgetRef ref) {
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: resetEmailController,
          decoration: const InputDecoration(labelText: 'Email Address'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dialogContext); // Close dialog
              
              try {
                await ref.read(authRepositoryProvider).resetPassword(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('7alabessa Auth')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.style, size: 80, color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Sign up"
                      : "Already have an account? Login",
                ),
              ),
              if (_isLogin)
                TextButton(
                  onPressed: () => _showForgotPasswordDialog(context, ref),
                  child: const Text('Forgot Password?'),
                ),
              const Divider(height: 32),
              const Text('Or connect with', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.g_mobiledata, size: 48, color: Colors.red),
                    onPressed: _isLoading ? null : () => _signInWithSocial(() => ref.read(authRepositoryProvider).signInWithGoogle()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.facebook, size: 40, color: Colors.blue),
                    onPressed: _isLoading ? null : () => _signInWithSocial(() => ref.read(authRepositoryProvider).signInWithFacebook()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.apple, size: 40),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Apple Sign-In is coming soon!')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 32),
              TextField(
                controller: _guestNameController,
                decoration: InputDecoration(
                  labelText: 'guest_nickname'.tr(),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInAnonymously,
                icon: const Icon(Icons.person_outline),
                label: Text('login'.tr()), // Using the translated "Login Anonymously" key
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
