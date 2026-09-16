import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/auth_providers.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/theme/theme_config.dart';
import '../../../../core/services/web_platform_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _guestNameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  late AnimationController _logoController;
  late AnimationController _particleController;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Set up immersive mode trigger for mobile browsers
    WebPlatformService.setupOneTimeFullscreenTrigger();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        _updateParticles();
      })..repeat();

    for (int i = 0; i < 30; i++) {
      _particles.add(Particle(
        position: Offset(_random.nextDouble(), _random.nextDouble()),
        velocity: Offset((_random.nextDouble() - 0.5) * 0.002, (_random.nextDouble() - 0.5) * 0.002),
        size: _random.nextDouble() * 3 + 1,
        opacity: _random.nextDouble() * 0.5 + 0.1,
      ));
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.position += p.velocity;
      if (p.position.dx < 0) p.position = Offset(1.0, p.position.dy);
      if (p.position.dx > 1) p.position = Offset(0.0, p.position.dy);
      if (p.position.dy < 0) p.position = Offset(p.position.dx, 1.0);
      if (p.position.dy > 1) p.position = Offset(p.position.dx, 0.0);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _guestNameController.dispose();
    _logoController.dispose();
    _particleController.dispose();
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
          _nameController.text.trim().isEmpty ? 'new_player_default'.tr() : _nameController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_nickname_error'.tr())),
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
    final resetEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: ThemeConfig.goldAccent.withOpacity(0.3))),
          title: Text('reset_password'.tr(), style: const TextStyle(color: Colors.white, fontFamily: ThemeConfig.fontHeading)),
          content: TextField(
            controller: resetEmailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('email_address'.tr(), Icons.email_rounded),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  await ref.read(authRepositoryProvider).resetPassword(email);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('verification_sent'.tr())));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.goldAccent, foregroundColor: Colors.black),
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
      prefixIcon: Icon(icon, color: ThemeConfig.primaryTeal.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ThemeConfig.primaryTeal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background Layer
          Positioned.fill(
            child: Image.asset(
              'assets/images/gaming/login_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    const Color(0xFF0D1B2A).withOpacity(0.8),
                    const Color(0xFF0D1B2A),
                  ],
                ),
              ),
            ),
          ),
          // Animated Particles
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(_particles, repaint: _particleController),
            ),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
              child: Column(
                children: [
                  // Logo with breathing animation
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
                    ),
                    child: Image.asset(
                      'assets/images/gaming/game_logo.png',
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Glassmorphism Login Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isLogin ? 'welcome_back'.tr() : 'create_account'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: ThemeConfig.fontHeading,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            
                            if (!_isLogin) ...[
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('display_name'.tr(), Icons.person_rounded),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              key: const ValueKey('login_email_field'),
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('email_address'.tr(), Icons.email_rounded),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const ValueKey('login_password_field'),
                              controller: _passwordController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('password'.tr(), Icons.lock_rounded),
                              obscureText: true,
                            ),
                            
                            if (_isLogin)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () => _showForgotPasswordDialog(context, ref),
                                  child: Text('forgot_password'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ),
                              )
                            else
                              const SizedBox(height: 24),

                            const SizedBox(height: 8),
                            
                            ElevatedButton(
                              key: const ValueKey('login_submit_btn'),
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeConfig.goldAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 8,
                                shadowColor: ThemeConfig.goldAccent.withOpacity(0.4),
                              ),
                              child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : Text(
                                    (_isLogin ? 'login_btn'.tr() : 'sign_up'.tr()).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                  ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            TextButton(
                              onPressed: () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? 'dont_have_account'.tr() : 'already_have_account'.tr(),
                                style: TextStyle(color: ThemeConfig.primaryTeal.withOpacity(0.9), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Social Login Section
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'or_connect_with'.tr().toUpperCase(),
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialButton(
                        icon: Icons.g_mobiledata,
                        color: Colors.redAccent,
                        onTap: () => _signInWithSocial(() => ref.read(authRepositoryProvider).signInWithGoogle()),
                      ),
                      const SizedBox(width: 20),
                      _socialButton(
                        icon: Icons.facebook_rounded,
                        color: Colors.blueAccent,
                        onTap: () => _signInWithSocial(() => ref.read(authRepositoryProvider).signInWithFacebook()),
                      ),
                      const SizedBox(width: 20),
                      _socialButton(
                        icon: Icons.apple_rounded,
                        color: Colors.white,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('apple_signin_soon'.tr())));
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Guest Login Section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _guestNameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('guest_nickname'.tr(), Icons.badge_outlined),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _isLoading ? null : _signInAnonymously,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: ThemeConfig.primaryTeal.withOpacity(0.5)),
                                foregroundColor: ThemeConfig.primaryTeal,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('login'.tr().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Language Selector (Top Right)
          Positioned(
            top: 50,
            right: 16,
            child: _languageSelector(context),
          ),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _languageSelector(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: const Icon(Icons.language_rounded, color: Colors.white70, size: 20),
      ),
      offset: const Offset(0, 45),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white10)),
      onSelected: (locale) => context.setLocale(locale),
      itemBuilder: (context) => [
        PopupMenuItem(value: const Locale('en', 'US'), child: Text('english'.tr(), style: const TextStyle(color: Colors.white70))),
        PopupMenuItem(value: const Locale('ar', 'EG'), child: Text('arabic_eg'.tr(), style: const TextStyle(color: Colors.white70))),
        PopupMenuItem(value: const Locale('ar', 'SA'), child: Text('arabic_sa'.tr(), style: const TextStyle(color: Colors.white70))),
      ],
    );
  }
}

class Particle {
  Offset position;
  Offset velocity;
  double size;
  double opacity;
  Particle({required this.position, required this.velocity, required this.size, required this.opacity});
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles, {super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ThemeConfig.primaryTeal;
    for (var p in particles) {
      paint.color = ThemeConfig.primaryTeal.withOpacity(p.opacity);
      canvas.drawCircle(Offset(p.position.dx * size.width, p.position.dy * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
