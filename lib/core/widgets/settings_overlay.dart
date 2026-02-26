import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';

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
        padding: const EdgeInsets.all(24),
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
              'sound_effects'.tr(),
              Icons.volume_up_rounded,
              settings.isSoundEnabled,
              (val) => notifier.toggleSound(val),
            ),
            _buildToggleTile(
              context,
              'music'.tr(),
              Icons.music_note_rounded,
              settings.isMusicEnabled,
              (val) => notifier.toggleMusic(val),
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
            const SizedBox(height: 40),
          ],
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
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: ThemeConfig.goldAccent),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: ThemeConfig.goldAccent,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLangButton(context, ref, 'English', const Locale('en', 'US'), currentLocale),
        _buildLangButton(context, ref, 'عربي (مصر)', const Locale('ar', 'EG'), currentLocale),
        _buildLangButton(context, ref, 'عربي (سعودي)', const Locale('ar', 'SA'), currentLocale),
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
}
