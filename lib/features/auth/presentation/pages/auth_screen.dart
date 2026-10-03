import 'package:halabessa/core/widgets/lantern_page_frame.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../providers/auth_providers.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/theme/theme_config.dart';
import '../../../../core/services/web_platform_service.dart';

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
  void initState() {
    super.initState();
    WebPlatformService.setupOneTimeFullscreenTrigger();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isLoading) return;
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
          _nameController.text.trim().isEmpty
              ? 'new_player_default'.tr()
              : _nameController.text.trim(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInAnonymously() async {
    if (_isLoading) return;
    final guestName = _guestNameController.text.trim();
    if (guestName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('enter_nickname_error'.tr())));
      return;
    }

    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    try {
      await authRepo.signInAnonymously(displayName: guestName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInWithSocial(Future<void> Function() signInMethod) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await signInMethod();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog(BuildContext context, WidgetRef ref) {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: ThemeConfig.goldAccent.withOpacity(0.3)),
          ),
          title: Text(
            'reset_password'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: ThemeConfig.fontHeading,
            ),
          ),
          content: TextField(
            controller: resetEmailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              'email_address'.tr(),
              Icons.email_rounded,
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  await ref.read(authRepositoryProvider).resetPassword(email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('verification_sent'.tr())),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ErrorHandler.getAuthErrorMessage(e)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.goldAccent,
                foregroundColor: Colors.black,
              ),
              child: Text('send_link'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
      prefixIcon: Icon(
        icon,
        color: ThemeConfig.primaryTeal.withOpacity(0.7),
        size: 20,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: ThemeConfig.primaryTeal,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _languageSelector(context),
                  ),
                  const LanternWordmark(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final asset in const [
                          'lantern_rival_man_v1.png',
                          'lantern_partner_v1.png',
                          'lantern_rival_woman_v1.png',
                        ])
                          Flexible(
                            child: Image.asset(
                              'assets/images/avatars/$asset',
                              height: 140,
                              excludeFromSemantics: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeConfig.surfaceGlass,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ThemeConfig.goldAccent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _guestNameController,
                          style: const TextStyle(color: Color(0xFFFFF6E7)),
                          decoration: _inputDecoration(
                            'guest_nickname'.tr(),
                            Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _signInAnonymously,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text('play_as_guest'.tr()),
                          style: FilledButton.styleFrom(
                            backgroundColor: ThemeConfig.goldAccent,
                            foregroundColor: const Color(0xFF192638),
                            minimumSize: const Size(48, 56),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'or_connect_with'.tr(),
                    style: const TextStyle(color: Color(0xFFFFF6E7)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _signInWithSocial(
                                () => ref
                                    .read(authRepositoryProvider)
                                    .signInWithGoogle(),
                              ),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _signInWithSocial(
                                () => ref
                                    .read(authRepositoryProvider)
                                    .signInWithFacebook(),
                              ),
                        icon: const Icon(Icons.facebook_rounded),
                        label: const Text('Facebook'),
                      ),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS)
                        SizedBox(
                          width: 260,
                          height: 50,
                          child: SignInWithAppleButton(
                            style: SignInWithAppleButtonStyle.white,
                            onPressed: () {
                              if (!_isLoading) {
                                _signInWithSocial(
                                  () => ref
                                      .read(authRepositoryProvider)
                                      .signInWithApple(),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: ThemeConfig.surfaceGlass,
                    borderRadius: BorderRadius.circular(20),
                    child: ExpansionTile(
                      title: Text(
                        (_isLogin ? 'welcome_back' : 'create_account').tr(),
                      ),
                      textColor: const Color(0xFFFFF6E7),
                      collapsedTextColor: const Color(0xFFFFF6E7),
                      childrenPadding: const EdgeInsets.all(20),
                      children: [
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              'display_name'.tr(),
                              Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const ValueKey('login_email_field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            'email_address'.tr(),
                            Icons.email_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('login_password_field'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _inputDecoration(
                            'password'.tr(),
                            Icons.lock_rounded,
                          ),
                        ),
                        if (_isLogin)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () =>
                                  _showForgotPasswordDialog(context, ref),
                              child: Text('forgot_password'.tr()),
                            ),
                          ),
                        FilledButton(
                          key: const ValueKey('login_submit_btn'),
                          onPressed: _isLoading ? null : _submit,
                          child: Text(
                            (_isLogin ? 'login_btn' : 'sign_up').tr(),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            (_isLogin
                                    ? 'dont_have_account'
                                    : 'already_have_account')
                                .tr(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _languageSelector(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: const Icon(
          Icons.language_rounded,
          color: Colors.white70,
          size: 20,
        ),
      ),
      offset: const Offset(0, 45),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white10),
      ),
      onSelected: (locale) => context.setLocale(locale),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('en', 'US'),
          child: Text(
            'english'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        PopupMenuItem(
          value: const Locale('ar', 'EG'),
          child: Text(
            'arabic_eg'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        PopupMenuItem(
          value: const Locale('ar', 'SA'),
          child: Text(
            'arabic_sa'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
