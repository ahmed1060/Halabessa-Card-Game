import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';

class UsernameOnboardingOverlay extends ConsumerStatefulWidget {
  const UsernameOnboardingOverlay({super.key});

  @override
  ConsumerState<UsernameOnboardingOverlay> createState() => _UsernameOnboardingOverlayState();
}

class _UsernameOnboardingOverlayState extends ConsumerState<UsernameOnboardingOverlay> {
  final _controller = TextEditingController();
  String? _error;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _isSaving = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _error = null;
        _isAvailable = false;
        _isChecking = false;
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _error = 'min_3_chars'.tr();
        _isAvailable = false;
        _isChecking = false;
      });
      return;
    }

    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(username)) {
      setState(() {
        _error = 'invalid_chars'.tr();
        _isAvailable = false;
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final currentUid = ref.read(currentUserProvider)?.uid;
      final available = await ref.read(authRepositoryProvider).isUsernameAvailable(username, currentUid: currentUid);
      setState(() {
        _isAvailable = available;
        _error = available ? null : 'username_taken'.tr();
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _error = 'error_general'.tr(args: [e.toString()]);
        _isChecking = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_isAvailable || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(username: _controller.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('username_updated_success'.tr())),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Force username selection
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle (Visual only as we don't want them to slide it down)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'onboarding_title'.tr(),
                style: const TextStyle(
                  color: ThemeConfig.goldAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: ThemeConfig.fontHeading,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'onboarding_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              Text(
                'onboarding_desc'.tr(),
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Input Field
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: 'enter_username_hint'.tr(),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: ThemeConfig.goldAccent),
                  suffixIcon: _isChecking 
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeConfig.goldAccent)))
                    : (_isAvailable ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent) : null),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  errorText: _error,
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeConfig.primaryTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeConfig.primaryTeal.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: ThemeConfig.primaryTeal, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'first_time_free'.tr(),
                          style: const TextStyle(color: ThemeConfig.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ticket_required_desc'.tr(),
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Button
              GestureDetector(
                onTap: (_isAvailable && !_isSaving) ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isAvailable ? ThemeConfig.primaryTeal : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (_isAvailable)
                        BoxShadow(color: ThemeConfig.primaryTeal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'save'.tr(),
                        style: TextStyle(
                          color: _isAvailable ? Colors.white : Colors.white24,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
