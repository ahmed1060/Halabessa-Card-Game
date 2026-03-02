import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';

class SettingsOverlay extends ConsumerWidget {
  const SettingsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'settings'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: ThemeConfig.goldAccent,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Audio Section
              _buildSectionHeader(context, 'audio'.tr()),
              _buildToggleTile(
                context,
                'music'.tr(),
                Icons.music_note_rounded,
                settings.isMusicEnabled,
                (val) => notifier.toggleMusic(val),
                isAdmin: ref.watch(currentUserProvider)?.isAdmin ?? false,
                onManage: () => Navigator.pushNamed(context, '/admin/music'),
              ),
              _buildToggleTile(
                context,
                'sound_effects'.tr(),
                Icons.volume_up_rounded,
                settings.isSoundEnabled,
                (val) => notifier.toggleSound(val),
                isAdmin: ref.watch(currentUserProvider)?.isAdmin ?? false,
                onManage: () => Navigator.pushNamed(context, '/admin/sfx'),
              ),
              _buildToggleTile(
                context,
                'haptic_feedback'.tr(),
                Icons.vibration_rounded,
                settings.isHapticsEnabled,
                (val) => notifier.toggleHaptics(val),
              ),
              const SizedBox(height: 24),

              // Language Section
              _buildSectionHeader(context, 'language'.tr()),
              const SizedBox(height: 12),
              _buildLanguageSelector(context, ref),
              const SizedBox(height: 24),

              // Theme Section
              _buildSectionHeader(context, 'theme'.tr()),
              const SizedBox(height: 12),
              _buildThemeSelector(context, ref),
              const SizedBox(height: 24),

              // Admin Actions (Optional)
              if (ref.watch(currentUserProvider)?.isAdmin ?? false) ...[
                _buildSectionHeader(context, 'admin_actions'.tr()),
                _buildAdminTile(
                  context,
                  'manage_users'.tr(),
                  Icons.admin_panel_settings_rounded,
                  () => Navigator.pushNamed(context, '/admin/users'),
                ),
                _buildAdminTile(
                  context,
                  'manage_sfx'.tr(),
                  Icons.volume_up_rounded,
                  () => Navigator.pushNamed(context, '/admin/sfx'),
                ),
                _buildAdminTile(
                  context,
                  'manage_music'.tr(),
                  Icons.music_note_rounded,
                  () => Navigator.pushNamed(context, '/admin/music'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context,
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isAdmin = false,
    VoidCallback? onManage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: ThemeConfig.goldAccent),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin && onManage != null)
              IconButton(
                icon: const Icon(Icons.settings_suggest, color: ThemeConfig.goldAccent, size: 20),
                onPressed: onManage,
                tooltip: 'manage_audio'.tr(),
              ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: ThemeConfig.goldAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLangButton(context, ref, 'english'.tr(), const Locale('en', 'US'), currentLocale),
        _buildLangButton(context, ref, 'arabic_eg'.tr(), const Locale('ar', 'EG'), currentLocale),
        _buildLangButton(context, ref, 'arabic_sa'.tr(), const Locale('ar', 'SA'), currentLocale),
      ],
    );
  }

  Widget _buildLangButton(BuildContext context, WidgetRef ref, String label, Locale locale, Locale current) {
    final isSelected = current == locale;
    return GestureDetector(
      onTap: () {
        context.setLocale(locale);
        ref.read(settingsProvider.notifier).setLanguage(locale.languageCode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ThemeConfig.goldAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Row(
      children: [
        Expanded(child: _buildThemeButton(context, 'light_mode'.tr(), ThemeMode.light, settings.themeMode, (m) => notifier.setThemeMode(m))),
        const SizedBox(width: 12),
        Expanded(child: _buildThemeButton(context, 'dark_mode'.tr(), ThemeMode.dark, settings.themeMode, (m) => notifier.setThemeMode(m))),
        const SizedBox(width: 12),
        Expanded(child: _buildThemeButton(context, 'system_mode'.tr(), ThemeMode.system, settings.themeMode, (m) => notifier.setThemeMode(m))),
      ],
    );
  }

  Widget _buildThemeButton(BuildContext context, String label, ThemeMode mode, ThemeMode current, ValueChanged<ThemeMode> onTap) {
    final isSelected = current == mode;
    return GestureDetector(
      onTap: () => onTap(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ThemeConfig.goldAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThemeConfig.goldAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: ThemeConfig.goldAccent),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, color: ThemeConfig.goldAccent),
        onTap: onTap,
      ),
    );
  }
}
