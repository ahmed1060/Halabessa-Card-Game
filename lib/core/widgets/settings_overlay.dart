import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/services/multimedia_service.dart';

class SettingsOverlay extends ConsumerWidget {
  const SettingsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final multimedia = ref.read(multimediaServiceProvider);
    final user = ref.watch(currentUserProvider);
    final currentLocale = context.locale;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E).withOpacity(0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(context),
                  
                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('audio'.tr()),
                          _buildToggleTile(
                            'music'.tr(),
                            settings.isMusicEnabled,
                            Icons.music_note_rounded,
                            (val) {
                              notifier.toggleMusic(val);
                              multimedia.vibrate();
                            },
                          ),
                          _buildToggleTile(
                            'sound_effects'.tr(),
                            settings.isSoundEnabled,
                            Icons.volume_up_rounded,
                            (val) {
                              notifier.toggleSound(val);
                              multimedia.vibrate();
                            },
                          ),
                          _buildToggleTile(
                            'haptic_feedback'.tr(),
                            settings.isHapticsEnabled,
                            Icons.vibration_rounded,
                            (val) {
                              notifier.toggleHaptics(val);
                              HapticFeedback.mediumImpact();
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          _buildSectionTitle('language'.tr()),
                          _buildLanguageGrid(context, currentLocale),
                          
                          const SizedBox(height: 24),
                          _buildSectionTitle('theme'.tr()),
                          _buildThemeSelector(settings.themeMode, notifier, multimedia),

                          if (user?.isAdmin == true) ...[
                            const SizedBox(height: 32),
                            _buildAdminButton(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeConfig.goldAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_suggest_rounded, color: ThemeConfig.goldAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                'settings'.tr(),
                style: const TextStyle(
                  fontFamily: ThemeConfig.fontHeading,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: ThemeConfig.goldAccent.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildToggleTile(String title, bool value, IconData icon, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        secondary: Icon(icon, color: Colors.white70, size: 20),
        activeColor: ThemeConfig.goldAccent,
        activeTrackColor: ThemeConfig.goldAccent.withOpacity(0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLanguageGrid(BuildContext context, Locale currentLocale) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildLanguageCard(context, 'english'.tr(), const Locale('en', 'US'), currentLocale),
        _buildLanguageCard(context, 'arabic_eg'.tr(), const Locale('ar', 'EG'), currentLocale),
        _buildLanguageCard(context, 'arabic_sa'.tr(), const Locale('ar', 'SA'), currentLocale),
      ],
    );
  }

  Widget _buildLanguageCard(BuildContext context, String label, Locale locale, Locale currentLocale) {
    final isSelected = currentLocale == locale;
    return GestureDetector(
      onTap: () => context.setLocale(locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ThemeConfig.goldAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ThemeConfig.goldAccent.withOpacity(0.5) : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) 
              const Icon(Icons.check_circle_rounded, color: ThemeConfig.goldAccent, size: 14),
            if (isSelected) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeMode currentMode, SettingsNotifier notifier, MultimediaService multimedia) {
    return Row(
      children: [
        _buildThemeOption(Icons.light_mode_rounded, ThemeMode.light, currentMode, () => notifier.setThemeMode(ThemeMode.light)),
        const SizedBox(width: 12),
        _buildThemeOption(Icons.dark_mode_rounded, ThemeMode.dark, currentMode, () => notifier.setThemeMode(ThemeMode.dark)),
        const SizedBox(width: 12),
        _buildThemeOption(Icons.settings_brightness_rounded, ThemeMode.system, currentMode, () => notifier.setThemeMode(ThemeMode.system)),
      ],
    );
  }

  Widget _buildThemeOption(IconData icon, ThemeMode mode, ThemeMode currentMode, VoidCallback onTap) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? ThemeConfig.goldAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ThemeConfig.goldAccent.withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }

  Widget _buildAdminButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ThemeConfig.goldAccent.withOpacity(0.2), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
      ),
      child: ListTile(
        onTap: () {
           // Navigate to admin management if needed, or show admin status
        },
        leading: const Icon(Icons.admin_panel_settings_rounded, color: ThemeConfig.goldAccent),
        title: Text('admin_label'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, color: ThemeConfig.goldAccent),
      ),
    );
  }
}
